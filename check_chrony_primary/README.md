# check_chrony_primary

Nagios plugin that verifies Chrony has selected a primary NTP source and checks its system tracking offset and RMS offset against configured thresholds.

The selected primary is identified from `chronyc sources -n`. Offset metrics come from `chronyc tracking`, so they describe Chrony’s system tracking state rather than measurements for that individual peer. The plugin reports RMS offset as jitter.

## Features

- Verifies that a primary Chrony source is selected (`^*`)
- Checks the absolute value of the clock offset against warning and critical thresholds
- Optionally checks RMS offset, reported as jitter
- Supports local and remote Chrony queries
- Returns standard Nagios plugin status codes
- Provides offset and jitter performance data for graphing and trending

## Requirements

- Bash
- Chrony (`chronyc`)
- `bc`

## Usage

```text
check_chrony_primary.sh [-H host] -w offset[,jitter] -c offset[,jitter]
