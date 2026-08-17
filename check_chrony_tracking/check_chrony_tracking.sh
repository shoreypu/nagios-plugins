#!/bin/bash
#
# check_chrony_tracking.sh
#
# Nagios plugin to validate Chrony synchronization state using:
#   chronyc tracking
#
# This check answers the core monitoring questions:
#   * Is the system clock synchronized?
#   * Is Chrony tracking a valid time reference?
#   * Is the current system offset within acceptable bounds?
#
# Unlike peer-based checks, this script does NOT depend on which NTP
# server is selected. It relies on Chrony’s authoritative view of
# synchronization state and clock correctness.
#
# WHEN TO USE THIS CHECK
# ---------------------
# * This is the preferred check for authoritative time health.
# * It is resilient to public NTP service behavior and formatting changes.
# * It avoids false alerts caused by peer rotation or LastRx aging.
#
# For cases where customers explicitly require confirmation that a
# primary peer (^*) is selected, see check_chrony_primary.sh.
#
# IMPORTANT NOTES
# ---------------
# * This script uses `chronyc tracking`, which is designed for automation.
# * If Chrony is not synchronized, `tracking` will explicitly report:
#     - Leap status: Not synchronised
#     - Stratum: 0
#     - An invalid or empty Reference ID
#
# * Offset represents actual system clock error and is authoritative.
# * Jitter (RMS offset) represents measurement stability over time.
#   Elevated jitter may occur without incorrect system time, especially
#   when using public NTP services.
#
# USAGE
# -----
#   check_chrony_tracking.sh [-H <host>] -w <warn>[,<jitter>] -c <crit>[,<jitter>]
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
# Offset thresholds are always enforced and determine overall state.
# Jitter thresholds are OPTIONAL and enforced only if provided.
#
# EXAMPLES
# --------
# Offset only (recommended default):
#   -w 0.001 -c 0.002
#
# Offset + jitter monitoring:
#   -w 0.001,0.010 -c 0.002,0.050
#
# NAGIOS BEHAVIOR
# ---------------
# * CRITICAL if Chrony is not synchronized
# * CRITICAL if offset exceeds critical threshold
# * WARNING if offset exceeds warning threshold
# * Jitter affects state only when thresholds are explicitly configured
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

OFFSET_WARN=${WARN%%,*}
JITTER_WARN=${WARN#*,}
OFFSET_CRIT=${CRIT%%,*}
JITTER_CRIT=${CRIT#*,}

[ "$OFFSET_WARN" = "$JITTER_WARN" ] && JITTER_WARN=""
[ "$OFFSET_CRIT" = "$JITTER_CRIT" ] && JITTER_CRIT=""

if [ -n "$HOST" ]; then
    TRACKING=$(chronyc -h "$HOST" tracking 2>/dev/null)
else
    TRACKING=$(chronyc tracking 2>/dev/null)
fi

[ -z "$TRACKING" ] && echo "UNKNOWN - Unable to query chrony tracking" && exit 3

LEAP=$(echo "$TRACKING" | awk -F': ' '/Leap status/ {print $2}')
STRATUM=$(echo "$TRACKING" | awk -F': ' '/Stratum/ {print $2}')
SYS_OFFSET=$(echo "$TRACKING" | awk -F': ' '/System time/ {print $2}' | awk '{print $1}')
RMS_OFFSET=$(echo "$TRACKING" | awk -F': ' '/RMS offset/ {print $2}' | awk '{print $1}')

OFFSET=${SYS_OFFSET#-}

if [[ "$LEAP" != "Normal" ]] || [[ "$STRATUM" -eq 0 ]]; then
    echo "CRITICAL - Chrony not synchronized (Leap='$LEAP', Stratum=$STRATUM)"
    exit 2
fi

if (( $(echo "$OFFSET > $OFFSET_CRIT" | bc -l) )); then
    echo "CRITICAL - System offset=${SYS_OFFSET}s | offset=${SYS_OFFSET}s jitter=${RMS_OFFSET}s"
    exit 2
elif (( $(echo "$OFFSET > $OFFSET_WARN" | bc -l) )); then
    echo "WARNING - System offset=${SYS_OFFSET}s | offset=${SYS_OFFSET}s jitter=${RMS_OFFSET}s"
    exit 1
fi

if [ -n "$JITTER_CRIT" ] && (( $(echo "$RMS_OFFSET > $JITTER_CRIT" | bc -l) )); then
    echo "CRITICAL - RMS jitter=${RMS_OFFSET}s | offset=${SYS_OFFSET}s jitter=${RMS_OFFSET}s"
    exit 2
elif [ -n "$JITTER_WARN" ] && (( $(echo "$RMS_OFFSET > $JITTER_WARN" | bc -l) )); then
    echo "WARNING - RMS jitter=${RMS_OFFSET}s | offset=${SYS_OFFSET}s jitter=${RMS_OFFSET}s"
    exit 1
fi

echo "OK - Chrony synchronized offset=${SYS_OFFSET}s jitter=${RMS_OFFSET}s | offset=${SYS_OFFSET}s jitter=${RMS_OFFSET}s"
exit 0
