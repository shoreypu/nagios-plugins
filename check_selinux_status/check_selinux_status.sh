#!/bin/bash

print_help() {
    cat <<EOF
Usage: $0 -s <expected_state>

Checks SELinux status against expected state.

Options:
  -s <state>   Expected SELinux state (enforcing, permissive, disabled)
  -h           Show this help message

Exit codes:
  0 OK
  1 WARNING
  2 CRITICAL
  3 UNKNOWN
EOF
}

# Parse args
while getopts ":s:h" opt; do
  case $opt in
    s) expected_state=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]') ;;
    h) print_help; exit 3 ;;
    \?) echo "UNKNOWN: Invalid option -$OPTARG"; print_help; exit 3 ;;
    :) echo "UNKNOWN: Option -$OPTARG requires an argument."; print_help; exit 3 ;;
  esac
done

if [[ -z "${expected_state:-}" ]]; then
    echo "UNKNOWN: No expected state provided"
    print_help
    exit 3
fi

# Read actual SELinux status
status_raw=$(getenforce 2>/dev/null || true)
if [[ -z "$status_raw" ]]; then
    echo "UNKNOWN: getenforce not available or returned empty"
    exit 3
fi

status=$(echo "$status_raw" | tr '[:upper:]' '[:lower:]')

case "$status" in
  enforcing|permissive|disabled) ;;
  *) echo "UNKNOWN: SELinux status is $status_raw"; exit 3 ;;
esac

# If matches expected -> OK
if [[ "$status" == "$expected_state" ]]; then
    echo "OK: SELinux is $status_raw (as expected)"
    exit 0
fi

# Mismatch -> map to WARNING/CRITICAL per your rules
case "$expected_state" in
  enforcing)
    # expected enforcing:
    #   permissive -> WARNING
    #   disabled  -> CRITICAL
    if [[ "$status" == "permissive" ]]; then
        echo "WARNING: SELinux is $status_raw (expected Enforcing)"
        exit 1
    else
        echo "CRITICAL: SELinux is $status_raw (expected Enforcing)"
        exit 2
    fi
    ;;
  permissive)
    # expected permissive:
    #   enforcing -> WARNING
    #   disabled  -> CRITICAL
    if [[ "$status" == "enforcing" ]]; then
        echo "WARNING: SELinux is $status_raw (expected Permissive)"
        exit 1
    else
        echo "CRITICAL: SELinux is $status_raw (expected Permissive)"
        exit 2
    fi
    ;;
  disabled)
    # expected disabled:
    #   permissive -> WARNING
    #   enforcing -> CRITICAL
    if [[ "$status" == "permissive" ]]; then
        echo "WARNING: SELinux is $status_raw (expected Disabled)"
        exit 1
    else
        echo "CRITICAL: SELinux is $status_raw (expected Disabled)"
        exit 2
    fi
    ;;
  *)
    echo "UNKNOWN: Invalid expected state '$expected_state' (use enforcing, permissive, or disabled)"
    exit 3
    ;;
esac
