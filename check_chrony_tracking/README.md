# check_chrony_tracking

Nagios plugin that checks Chrony's synchronization state and system clock offset using `chronyc tracking`.

The plugin considers Chrony synchronized when `Leap status` is `Normal` and `Stratum` is nonzero. It checks the absolute value of the `System time` offset against configured warning and critical thresholds. It also reports Chrony's `RMS offset` as jitter, with optional jitter thresholds.

This check does not depend on which NTP source is selected. Use `check_chrony_primary.sh` when monitoring must confirm that a primary source (`^*`) is selected.

## Features

- Checks Chrony's synchronization state using leap status and stratum
- Checks system offset against warning and critical thresholds
- Optionally checks RMS offset, reported as jitter
- Supports local and remote Chrony queries
- Returns standard Nagios plugin status codes
- Provides offset and jitter performance data
- Lightweight Bash implementation

## Requirements

- Bash
- Chrony (`chronyc`)
- `bc`

## Usage

```bash
check_chrony_tracking.sh [-H host] -w offset[,jitter] -c offset[,jitter]
