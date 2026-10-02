## Features

- Monitors the uptime of a named Windows process.
- Matches process names case-insensitively, with or without `.exe`.
- Uses the oldest readable matching instance when multiple instances are running.
- Supports optional warning and critical thresholds in hours.
- Reports Nagios-compatible status and performance data.

## Requirements

- A Windows host running the process to monitor.
- PowerShell with the `Get-CimInstance` cmdlet available.
- Permission to read the process start time. Protected processes may not expose it.
- For remote monitoring, NCPA on the Windows host and `check_ncpa.py` on the Nagios server.

## Usage

Run locally with both thresholds:

```powershell
.\check_process_uptime.ps1 -ProcessName w3wp.exe -WarningHours 24 -CriticalHours 36
```

Either threshold can be omitted:

```powershell
.\check_process_uptime.ps1 -ProcessName w3wp.exe -WarningHours 24
.\check_process_uptime.ps1 -ProcessName w3wp.exe -CriticalHours 36
```

For NCPA, place the script in the agent's `plugins` directory. Pass only the thresholds you are using.

Both thresholds:

```bash
$USER1$/check_ncpa.py -H $HOSTADDRESS$ -t $ARG1$ -M 'plugins/check_process_uptime.ps1' -a "ProcessName=$ARG2 WarningHours=$ARG3 CriticalHours=$ARG4"
```

Warning threshold only:

```bash
$USER1$/check_ncpa.py -H $HOSTADDRESS$ -t $ARG1$ -M 'plugins/check_process_uptime.ps1' -a "ProcessName=$ARG2 WarningHours=$ARG3"
```

Critical threshold only:

```bash
$USER1$/check_ncpa.py -H $HOSTADDRESS$ -t $ARG1$ -M 'plugins/check_process_uptime.ps1' -a "ProcessName=$ARG2 CriticalHours=$ARG4"
```

Do not pass an unused threshold as an empty value.

The plugin returns `0` for OK, `1` for WARNING, `2` for CRITICAL, and `3` for UNKNOWN. When both thresholds are configured, the critical threshold takes precedence.
