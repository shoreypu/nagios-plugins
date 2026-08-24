<#
.SYNOPSIS
    Nagios XI / NCPA check for IIS Application Pool status.

.DESCRIPTION
    This script checks the state of one or more IIS Application Pools and returns
    a Nagios-compatible status (OK, WARNING, or CRITICAL).

    - Read-only check (no start/stop actions performed)
    - Designed for use with Nagios XI via NCPA
    - Supports checking all pools or a specified list

.PARAMETER AppPools
    Comma-separated list of IIS Application Pool names to check.

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

.OUTPUT
    OK:
        All monitored app pools are in Started state

    WARNING:
        One or more app pools are in transitional states:
        - Starting
        - Stopping

    CRITICAL:
        One or more app pools are Stopped
        OR no matching app pools were found

    Includes performance data:
        running=<count> total=<count> stopped=<count> transitional=<count>

.NOTES
    Author: Adapted for Nagios XI use

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
    [Parameter(Mandatory=$false, Position=0)]
    [string]$AppPools = "All"
)

$ExitCode = 0
$StoppedList = @()
$TransitionalList = @()

# Handle input
if ([string]::IsNullOrWhiteSpace($AppPools) -or $AppPools -eq "All") {
    $AppPoolsList = "All"
} else {
    $AppPoolsList = $AppPools -split "," | ForEach-Object { $_.Trim() }
}

# Load module
Import-Module WebAdministration -ErrorAction SilentlyContinue

if (-not (Get-Module -Name WebAdministration)) {
    Write-Output "CRITICAL: WebAdministration module not available | running=0 total=0 stopped=0 transitional=0"
    Exit 2
}

$AllPools = Get-WebAppPoolState
$Total = 0
$Running = 0
$Transitional = 0

foreach ($Pool in $AllPools) {
    $Name = $Pool.ItemXPath.Split("'")[1]
    $State = $Pool.Value

    if (($AppPoolsList -eq "All") -or ($AppPoolsList -contains $Name)) {

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

# No matches
if ($Total -eq 0) {
    Write-Output "CRITICAL: No matching app pools found | running=0 total=0 stopped=0 transitional=0"
    Exit 2
}

# Determine status priority: CRITICAL > WARNING > OK
if ($StoppedList.Count -gt 0) {
    $ExitCode = 2
    $Output = "CRITICAL: Stopped AppPools: " + ($StoppedList -join ", ")
}
elseif ($TransitionalList.Count -gt 0) {
    $ExitCode = 1
    $Output = "WARNING: Transitional AppPools: " + ($TransitionalList -join ", ")
}
else {
    $Output = "OK: All AppPools running"
}

# Perfdata
$Output += " | running=$Running total=$Total stopped=$($StoppedList.Count) transitional=$Transitional"

Write-Output $Output
Exit $ExitCode
