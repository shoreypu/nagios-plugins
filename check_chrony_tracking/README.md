# check_chrony_tracking

Nagios plugin that validates Chrony synchronization health using `chronyc tracking`.

This check verifies that the system clock is synchronized, that Chrony is tracking a valid time reference, and that the current system offset remains within administrator-defined thresholds.

Unlike peer-based checks, this plugin does not depend on which NTP source is currently selected. It relies on Chrony's authoritative synchronization state and is the preferred method for monitoring overall time health.

## Features

- Verifies Chrony is synchronized
- Validates synchronization state using `chronyc tracking`
- Checks system offset against warning and critical thresholds
- Optional RMS jitter threshold monitoring
- Supports local and remote Chrony queries
- Returns standard Nagios plugin status codes
- Provides performance data for graphing
- Lightweight Bash implementation

## Requirements

- Bash
- Chrony (`chronyc`)
- bc

## Usage

```bash
check_chrony_tracking.sh [-H host] -w offset[,jitter] -c offset[,jitter]
```

## Threshold Format

Thresholds are specified in seconds.

Offset thresholds are always required.

Jitter thresholds are optional.

### Offset Only (Recommended)

```bash
check_chrony_tracking.sh -w 0.001 -c 0.002
```

### Offset and Jitter

```bash
check_chrony_tracking.sh -w 0.001,0.010 -c 0.002,0.050
```

### Remote Host

```bash
check_chrony_tracking.sh -H ntpserver.example.com -w 0.001 -c 0.002
```

## Example Output

### OK

```text
OK - Chrony synchronized offset=0.000123s jitter=0.000456s | offset=0.000123s jitter=0.000456s
```

### WARNING

```text
WARNING - System offset=0.001500s | offset=0.001500s jitter=0.000456s
```

