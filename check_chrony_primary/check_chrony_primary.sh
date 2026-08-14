#!/bin/bash
#
# check_chrony_primary.sh
#
# Nagios plugin to verify that Chrony:
#   1) Has selected a primary NTP peer (^*)
#   2) Reports acceptable offset and jitter for that peer
#
# This check is intentionally peer-focused to satisfy customers who require
# confirmation that a "primary" time source is selected.
#
# IMPORTANT NOTES
# ---------------
# * This script parses `chronyc sources -n`, which is human-oriented output.
# * Output fields such as LastRx may include alpha suffixes (e.g. 23m, 1h, -).
# * This script therefore uses pattern matching rather than fixed columns.
#
# * Offset represents current clock error and is authoritative.
# * Jitter represents measurement stability and may legitimately fluctuate
#   for public NTP services without indicating incorrect system time.
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
# Where all values are in SECONDS.
#
# Offset thresholds are always enforced.
# Jitter thresholds are OPTIONAL and enforced only if provided.
#
# EXAMPLES
# --------
# Offset only (legacy behavior):
#   -w 0.001 -c 0.002
#
# Offset + jitter:
#   -w 0.001,0.010 -c 0.002,0.050
#
# For authoritative synchronization health (peer-independent),
# see check_chrony_tracking.sh.
#

HOST=""
WARN=""
CRIT=""

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

if [ -n "$HOST" ]; then
    CMD="chronyc -h $HOST sources -n"
else
    CMD="chronyc sources -n"
fi

OUTPUT=$($CMD 2>/dev/null)
[ -z "$OUTPUT" ] && echo "UNKNOWN - Unable to query chrony" && exit 3

SOURCE_LINE=$(echo "$OUTPUT" | grep '^\^\*')
[ -z "$SOURCE_LINE" ] && echo "CRITICAL - No primary NTP source selected" && exit 2

SERVER=$(echo "$SOURCE_LINE" | awk '{print $2}')

# Extract offset and jitter safely
RAW_OFFSET=$(echo "$SOURCE_LINE" | grep -o '[-+][0-9]\+us\[' | tr -d 'us[')
RAW_JITTER=$(echo "$SOURCE_LINE" | grep -o '[0-9]\+us$' | sed 's/us//')

# Normalize signs
RAW_OFFSET=${RAW_OFFSET#[-+]}
RAW_JITTER=${RAW_JITTER#[-+]}

[ -z "$RAW_OFFSET" ] && echo "UNKNOWN - Unable to extract offset" && exit 3

OFFSET=$(echo "scale=6; $RAW_OFFSET / 1000000" | bc)
JITTER=$(echo "scale=6; $RAW_JITTER / 1000000" | bc)

# Evaluation logic
if (( $(echo "$OFFSET > $OFFSET_CRIT" | bc -l) )); then
    echo "CRITICAL - Primary $SERVER offset=${OFFSET}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 2
elif (( $(echo "$OFFSET > $OFFSET_WARN" | bc -l) )); then
    echo "WARNING - Primary $SERVER offset=${OFFSET}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 1
fi

# Optional jitter enforcement
if [ -n "$JITTER_CRIT" ] && (( $(echo "$JITTER > $JITTER_CRIT" | bc -l) )); then
    echo "CRITICAL - Primary $SERVER jitter=${JITTER}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 2
elif [ -n "$JITTER_WARN" ] && (( $(echo "$JITTER > $JITTER_WARN" | bc -l) )); then
    echo "WARNING - Primary $SERVER jitter=${JITTER}s | offset=${OFFSET}s jitter=${JITTER}s"
    exit 1
fi

echo "OK - Primary $SERVER offset=${OFFSET}s jitter=${JITTER}s | offset=${OFFSET}s jitter=${JITTER}s"
exit 0
