<#
.SYNOPSIS
    Nagios XI / NCPA check for IIS Application Pool status.

.DESCRIPTION
    This script checks the state of one or more IIS Application Pools and returns
    a Nagios-compatible status (OK, WARNING, or CRITICAL).

    - Read-only check (no start/stop actions performed)
    - Designed for use with Nagios XI via NCPA
    - Supports checking all pools or a specified list
    - Reports requested pools that do not exist

.PARAMETER AppPools
    Comma-separated list of IIS Application Pool names to check. Multiple
    arguments are also accepted because some NCPA callers split arguments at
    commas or whitespace.

    Examples:
        "DefaultAppPool"
        "AppPool1,AppPool2,AppPool3"

    If no value is provided, or if "All" is specified, the script will
    check the status of ALL IIS application pools.

.EXAMPLES
    Check all app pools (no argument required):
        .\check_iis_apppools.ps1

    Check all app pools (explicit):
        .\check_iis_apppools.ps1 "All"

    Check specific pools:
        .\check_iis_apppools.ps1 "AppPool1,AppPool2"

    Nagios XI / NCPA usage:

    Check all app pools:
        check_ncpa.py -H <host> -t <token> -P 5693 `
        -M 'plugins/check_iis_apppools.ps1'

    Check specific pools:
        check_ncpa.py -H <host> -t <token> -P 5693 `
        -M 'plugins/check_iis_apppools.ps1' `
        -a "AppPool1,AppPool2"

.OUTPUTS
    OK:
        All monitored app pools are in Started state

    WARNING:
        One or more app pools are in transitional states:
        - Starting
        - Stopping

    CRITICAL:
        One or more app pools are Stopped
        OR one or more requested app pools do not exist

    Includes performance data:
        running=<count> total=<count> stopped=<count> transitional=<count>
        missing=<count>

.NOTES
    VERSION CONTROL:
        Author: John Shorey
        Version: 1.2.1
        Last Updated: 2026-09-21

        Revision History:
            1.2.1 - Fixed the AppPool argument normalization pipeline before
                    de-duplication.
            1.2.0 - Strip quotes and surrounding whitespace from AppPool
                arguments and remove duplicate requests.
            1.1.0 - Accept multiple AppPool arguments, report missing pools, and
                    add missing-pool performance data.
            1.0.0 - Initial IIS AppPool status check.

    Requirements:
        - IIS PowerShell module (WebAdministration)
        - NCPA agent installed (for remote execution)

    Default script path:
        C:\Program Files\Nagios\NCPA\plugins\

    State handling:
        Started   = OK
        Starting  = WARNING
        Stopping  = WARNING
        Stopped   = CRITICAL

        NOTE:
        Transitional states (Starting/Stopping) are typically short-lived.
        Repeated WARNING alerts may indicate:
            - app pool instability
            - recycle loops
            - deployment issues

    Permissions:
        The account running this script (typically the NCPA service account)
        must have permission to query IIS.

        Recommended:
            - Run the NCPA service as a Local Administrator

        Alternative (least privilege):
            - Member of IIS_IUSRS group
            - Read access to IIS configuration (applicationHost.config)

    Testing:
        To verify permissions, run:

            Import-Module WebAdministration
            Get-WebAppPoolState

    Exit Codes:
        0 = OK
        1 = WARNING
        2 = CRITICAL
#>

Param(
    [Parameter(Mandatory=$false, Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$AppPools = @("All")
)

$ExitCode = 0
$StoppedList = @()
$TransitionalList = @()

# Handle input from either a single comma-separated argument or multiple
# arguments supplied by the caller.
$AppPoolsList = @(
    $AppPools |
        ForEach-Object { $_ -split "," } |
        ForEach-Object { $_.Trim(" `"`t") } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
)

if ($AppPoolsList.Count -eq 0 -or $AppPoolsList -contains "All") {
    $AppPoolsList = @("All")
}
$CheckAll = $AppPoolsList.Count -eq 1 -and $AppPoolsList[0] -ieq "All"

# Load module
Import-Module WebAdministration -ErrorAction SilentlyContinue

if (-not (Get-Module -Name WebAdministration)) {
    Write-Output "CRITICAL: WebAdministration module not available | running=0 total=0 stopped=0 transitional=0 missing=0"
    Exit 2
}

$AllPools = @()
try {
    $AllPools = @(Get-WebAppPoolState -ErrorAction Stop)
}
catch {
    Write-Output "CRITICAL: Unable to query IIS application pools: $($_.Exception.Message) | running=0 total=0 stopped=0 transitional=0 missing=0"
    Exit 2
}

$Total = 0
$Running = 0
$Transitional = 0
$FoundPools = @()

foreach ($Pool in $AllPools) {
    if ($Pool.ItemXPath -match "name='([^']+)'") {
        $Name = $Matches[1]
    }
    else {
        continue
    }

    $State = $Pool.Value

    if ($CheckAll -or ($AppPoolsList -contains $Name)) {

        $FoundPools += $Name

        $Total++

        switch ($State) {
            "Started" {
                $Running++
            }
            "Stopped" {
                $StoppedList += $Name
            }
            "Starting" {
                $Transitional++
                $TransitionalList += "$Name(Starting)"
            }
            "Stopping" {
                $Transitional++
                $TransitionalList += "$Name(Stopping)"
            }
            default {
                $Transitional++
                $TransitionalList += "$Name($State)"
            }
        }
    }
}

# Identify requested pools that were not returned by IIS.
$MissingPools = @()
if (-not $CheckAll) {
    $MissingPools = @($AppPoolsList | Where-Object { $FoundPools -notcontains $_ })
}

# No matches.
if ($Total -eq 0) {
    if ($MissingPools.Count -gt 0) {
        $Output = "CRITICAL: Missing AppPools: " + ($MissingPools -join ", ")
    }
    else {
        $Output = "CRITICAL: No IIS application pools found"
    }

    $Output += " | running=0 total=0 stopped=0 transitional=0 missing=$($MissingPools.Count)"
    Write-Output $Output
    Exit 2
}

# Determine status priority: missing/stopped > transitional > OK.
$Messages = @()
if ($MissingPools.Count -gt 0) {
    $Messages += "Missing AppPools: " + ($MissingPools -join ", ")
}
if ($StoppedList.Count -gt 0) {
    $Messages += "Stopped AppPools: " + ($StoppedList -join ", ")
}
if ($TransitionalList.Count -gt 0) {
    $Messages += "Transitional AppPools: " + ($TransitionalList -join ", ")
}

if ($MissingPools.Count -gt 0 -or $StoppedList.Count -gt 0) {
    $ExitCode = 2
    $Output = "CRITICAL: " + ($Messages -join "; ")
}
elseif ($TransitionalList.Count -gt 0) {
    $ExitCode = 1
    $Output = "WARNING: " + ($Messages -join "; ")
}
else {
    $Output = "OK: All AppPools running"
}

$Output += " | running=$Running total=$Total stopped=$($StoppedList.Count) transitional=$Transitional missing=$($MissingPools.Count)"
Write-Output $Output
Exit $ExitCode
