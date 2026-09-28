#!/bin/bash
#
# check_chrony_primary.sh
#
# Nagios plugin to verify that Chrony:
#   1) Has selected a primary NTP peer (^*)
#   2) Reports an acceptable clock offset and RMS offset for that peer
#
# VERSION CONTROL
# ---------------
# Author: John Shorey
# Version: 1.1.1
# Date: 2026-09-21
#
# Change history:
#   1.1.1 - Fixed small positive offsets being reformatted as scientific
#           notation before comparison with bc.
#   1.1.0 - Added signed offset handling, threshold validation, safe host
#           argument handling, and explicit UNKNOWN results for query or
#           evaluation failures.
#   1.0.0 - Initial peer-focused Chrony check.
#
# This check is intentionally peer-focused to satisfy customers who require
# confirmation that a "primary" time source is selected.
#
# IMPORTANT NOTES
# ---------------
# * Primary source selection is obtained from `chronyc sources -n`.
# * Offset and RMS offset metrics are obtained from `chronyc tracking`.
#
# * This approach avoids parsing human-oriented source statistics whose
#   displayed units may vary (ns, us, ms) depending on the magnitude
#   of the offset and error values.
#
# * Offset represents current clock error and is authoritative. Its absolute
#   magnitude is compared with the configured offset thresholds, so positive
#   and negative offsets of the same size produce the same result.
# * RMS offset is used as the stability metric and is displayed as jitter.
#
# * Output fields such as LastRx may include alpha suffixes
#   (e.g. 23m, 1h, -). Source selection is therefore determined
#   by the selected primary source marker (^*).
#
# USAGE
# -----
#   check_chrony_primary.sh [-H <host>] -w <warn>[,<jitter>] -c <crit>[,<jitter>]
#
# THRESHOLD FORMAT
# ----------------
# Thresholds may be specified as:
#
#   -w <offset> -c <offset>
#
# or:
#
#   -w <offset>,<jitter> -c <offset>,<jitter>
#
# Where all values are specified in SECONDS.
#
# Offset thresholds are always enforced and must be nonnegative.
# Jitter thresholds are OPTIONAL, must be nonnegative, and are enforced only
# if provided. Warning thresholds must not exceed critical thresholds.
#
# Invalid thresholds, missing Chrony data, command failures, and evaluation
# failures return UNKNOWN (exit code 3).
#
# EXAMPLES
# --------
# Offset only (legacy behavior):
#   -w 0.001 -c 0.002
#
# Offset + jitter:
#   -w 0.001,0.010 -c 0.002,0.050
#
# EXAMPLE OUTPUT
# --------------
#   OK - Primary time1.meta.com offset=+0.000045854s jitter=0.000102925s
#
# For authoritative synchronization health (peer-independent),
# see check_chrony_tracking.sh.


HOST=""
WARN=""
CRIT=""

is_nonnegative_number() {
    [[ "$1" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]
}

is_number() {
    [[ "$1" =~ ^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]
}

bc_compare() {
    local result
    result=$(printf '%s\n' "$1" | bc -l 2>/dev/null | tr -d '[:space:]') || return 1
    case "$result" in
        0|1) printf '%s\n' "$result" ;;
        *) return 1 ;;
    esac
}

usage() {
    echo "Usage: $0 -w warn[,jitter] -c crit[,jitter] [-H host]"
    exit 3
}

while getopts ":H:w:c:" opt; do
    case "$opt" in
        H) HOST="$OPTARG" ;;
        w) WARN="$OPTARG" ;;
        c) CRIT="$OPTARG" ;;
        *) usage ;;
    esac
done

[ -z "$WARN" ] || [ -z "$CRIT" ] && usage

# Split thresholds
OFFSET_WARN=${WARN%%,*}
JITTER_WARN=${WARN#*,}
OFFSET_CRIT=${CRIT%%,*}
JITTER_CRIT=${CRIT#*,}

# Handle single-value (no comma) case
[ "$OFFSET_WARN" = "$JITTER_WARN" ] && JITTER_WARN=""
[ "$OFFSET_CRIT" = "$JITTER_CRIT" ] && JITTER_CRIT=""

if ! command -v bc >/dev/null 2>&1; then
    echo "UNKNOWN - bc is required"
    exit 3
fi

for threshold in "$OFFSET_WARN" "$OFFSET_CRIT"; do
    if ! is_nonnegative_number "$threshold"; then
        echo "UNKNOWN - Invalid offset threshold"
        exit 3
    fi
done

for threshold in "$JITTER_WARN" "$JITTER_CRIT"; do
    if [ -n "$threshold" ] && ! is_nonnegative_number "$threshold"; then
        echo "UNKNOWN - Invalid jitter threshold"
        exit 3
    fi
done

if ! result=$(bc_compare "$OFFSET_WARN > $OFFSET_CRIT"); then
    echo "UNKNOWN - Unable to evaluate thresholds"
    exit 3
elif [ "$result" -eq 1 ]; then
    echo "UNKNOWN - Warning offset threshold exceeds critical threshold"
    exit 3
fi

if [ -n "$JITTER_WARN" ] && [ -n "$JITTER_CRIT" ]; then
    if ! result=$(bc_compare "$JITTER_WARN > $JITTER_CRIT"); then
        echo "UNKNOWN - Unable to evaluate thresholds"
        exit 3
    elif [ "$result" -eq 1 ]; then
        echo "UNKNOWN - Warning jitter threshold exceeds critical threshold"
        exit 3
    fi
fi

if [ -n "$HOST" ]; then
    if ! OUTPUT=$(chronyc -h "$HOST" sources -n 2>/dev/null); then
        echo "UNKNOWN - Unable to query chrony"
        exit 3
    fi
else
    if ! OUTPUT=$(chronyc sources -n 2>/dev/null); then
        echo "UNKNOWN - Unable to query chrony"
        exit 3
    fi
fi

[ -z "$OUTPUT" ] && echo "UNKNOWN - Unable to query chrony" && exit 3

SOURCE_LINE=$(echo "$OUTPUT" | grep -m1 '^\^\*')
[ -z "$SOURCE_LINE" ] && echo "CRITICAL - No primary NTP source selected" && exit 2

SERVER=$(echo "$SOURCE_LINE" | awk '{print $2}')

# Get offset and jitter from tracking output

if [ -n "$HOST" ]; then
    if ! TRACKING=$(chronyc -h "$HOST" tracking 2>/dev/null); then
        echo "UNKNOWN - Unable to query chrony tracking"
        exit 3
    fi
else
    if ! TRACKING=$(chronyc tracking 2>/dev/null); then
        echo "UNKNOWN - Unable to query chrony tracking"
        exit 3
    fi
fi

OFFSET=$(echo "$TRACKING" | awk -F': ' '/Last offset/ {print $2}' | awk '{print $1}')
JITTER=$(echo "$TRACKING" | awk -F': ' '/RMS offset/ {print $2}' | awk '{print $1}')

[ -z "$OFFSET" ] && echo "UNKNOWN - Unable to extract offset" && exit 3
[ -z "$JITTER" ] && echo "UNKNOWN - Unable to extract jitter" && exit 3

if ! is_number "$OFFSET"; then
    echo "UNKNOWN - Invalid offset returned by chrony"
    exit 3
fi

if ! is_nonnegative_number "$JITTER"; then
    echo "UNKNOWN - Invalid jitter returned by chrony"
    exit 3
fi

OFFSET_ABS=${OFFSET#+}
OFFSET_ABS=${OFFSET_ABS#-}

# Evaluation logic
if ! result=$(bc_compare "$OFFSET_ABS > $OFFSET_CRIT"); then
    echo "UNKNOWN - Unable to evaluate offset"
    exit 3
elif [ "$result" -eq 1 ]; then
    echo "CRITICAL - Primary $SERVER offset=${OFFSET}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 2
fi

if ! result=$(bc_compare "$OFFSET_ABS > $OFFSET_WARN"); then
    echo "UNKNOWN - Unable to evaluate offset"
    exit 3
elif [ "$result" -eq 1 ]; then
    echo "WARNING - Primary $SERVER offset=${OFFSET}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 1
fi

# Optional jitter enforcement
if [ -n "$JITTER_CRIT" ]; then
    if ! result=$(bc_compare "$JITTER > $JITTER_CRIT"); then
        echo "UNKNOWN - Unable to evaluate jitter"
        exit 3
    elif [ "$result" -eq 1 ]; then
    echo "CRITICAL - Primary $SERVER jitter=${JITTER}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 2
    fi
fi

if [ -n "$JITTER_WARN" ]; then
    if ! result=$(bc_compare "$JITTER > $JITTER_WARN"); then
        echo "UNKNOWN - Unable to evaluate jitter"
        exit 3
    elif [ "$result" -eq 1 ]; then
    echo "WARNING - Primary $SERVER jitter=${JITTER}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 1
    fi
fi

echo "OK - Primary $SERVER offset=${OFFSET}s jitter=${JITTER}s | offset=${OFFSET}s jitter=${JITTER}s"
exit 0

