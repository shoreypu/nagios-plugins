# check_iis_apppools

Nagios XI / NCPA plugin that validates IIS Application Pool health using the PowerShell `WebAdministration` module.

This check verifies that one or more IIS Application Pools are running and returns Nagios-compatible status codes based on their current state.

The plugin can monitor all application pools or a specified subset and includes performance data suitable for graphing and reporting.

## Features

- Verifies IIS Application Pool status
- Monitors all application pools or selected pools
- Detects stopped application pools as CRITICAL
- Detects starting and stopping pools as WARNING
- Handles unexpected application pool states
- Returns standard Nagios plugin status codes
- Provides performance data for graphing
- Read-only operation (no start/stop actions performed)
- Designed for Nagios XI and NCPA environments

## Requirements

- Windows Server with IIS installed
- PowerShell
- IIS PowerShell Module (`WebAdministration`)
- NCPA Agent

## Usage

### Check All Application Pools

```powershell
check_iis_apppools.ps1
```

or

```powershell
check_iis_apppools.ps1 All
```

### Check Specific Application Pools

```powershell
check_iis_apppools.ps1 "DefaultAppPool"
```

```powershell
check_iis_apppools.ps1 "AppPool1,AppPool2"
```

### NCPA Example

Check all application pools:

```bash
check_ncpa.py -H <host> -t <token> -P 5693 \
-M "plugins/check_iis_apppools.ps1"
```

Check specific application pools:

```bash
check_ncpa.py -H <host> -t <token> -P 5693 \
-M "plugins/check_iis_apppools.ps1" \
-a "AppPool1,AppPool2"
```

## State Mapping

| IIS State | Nagios Status |
|-----------|---------------|
| Started | OK |
| Starting | WARNING |
| Stopping | WARNING |
| Stopped | CRITICAL |
| Any Other State | WARNING |

## Example Output

### OK

```text
OK: All AppPools running | running=8 total=8 stopped=0 transitional=0
```

### WARNING

```text
WARNING: Transitional AppPools: MyAppPool(Starting) | running=7 total=8 stopped=0 transitional=1
```

```text
WARNING: Transitional AppPools: WebPool(Stopping) | running=5 total=6 stopped=0 transitional=1
```

### CRITICAL

```text
CRITICAL: Stopped AppPools: MyAppPool | running=7 total=8 stopped=1 transitional=0
```

### No Matching Application Pools

```text
CRITICAL: No matching app pools found | running=0 total=0 stopped=0 transitional=0
```

### Missing IIS Module

```text
CRITICAL: WebAdministration module not available | running=0 total=0 stopped=0 transitional=0
```

## Performance Data

The plugin returns the following performance metrics:

```text
running=<count>
total=<count>
stopped=<count>
transitional=<count>
```

Example:

```text
running=12 total=15 stopped=2 transitional=1
```

## Installation

Copy the script to the NCPA plugins directory:

```text
C:\Program Files\Nagios\NCPA\plugins\
```

Ensure the account running the NCPA service has permission to query IIS Application Pool status.

## Testing

Verify the IIS PowerShell module is available:

```powershell
Import-Module WebAdministration
Get-WebAppPoolState
```

## Exit Codes

```text
0 = OK
1 = WARNING
2 = CRITICAL
```

## License

MIT License

## Author

John Shorey
