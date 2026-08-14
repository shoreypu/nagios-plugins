# check_chrony_primary

Nagios plugin that verifies Chrony has selected a primary NTP source and validates offset and optional jitter thresholds for the selected source.

This check is intended for environments where monitoring must confirm that Chrony has an active primary source in addition to verifying synchronization quality.

## Features

- Verifies a primary Chrony source is selected (`^*`)
- Checks offset against warning and critical thresholds
- Optional jitter threshold monitoring
- Supports local and remote Chrony queries
- Returns standard Nagios plugin status codes
- Provides performance data for graphing and trending

## Requirements

- Bash
- Chrony (`chronyc`)
- bc

## Usage

```bash
check_chrony_primary.sh [-H host] -w offset[,jitter] -c offset[,jitter]
