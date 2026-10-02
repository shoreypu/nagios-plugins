
<#
.SYNOPSIS
  Nagios/NCPA plugin to alert on Windows process uptime.

.DESCRIPTION
  - Case-insensitive match on the process name you pass (e.g., 'w3wp' or 'w3wp.exe').
  - Uses the oldest matching instance for uptime (useful for multi-instance processes).
  - Returns UNKNOWN (3) if the process is not found or no readable StartTime.
  - Both -WarningHours and -CriticalHours are OPTIONAL; you may set warning-only, critical-only, or both.

.LOCAL COMMAND EXAMPLES
  # WARNING + CRITICAL
  ./check_process_uptime.ps1 -ProcessName w3wp.exe -WarningHours 24 -CriticalHours 36

  # WARNING-only
  ./check_process_uptime.ps1 -ProcessName w3wp.exe -WarningHours 24

  # CRITICAL-only
  ./check_process_uptime.ps1 -ProcessName w3wp.exe -CriticalHours 36

.NCPA COMMAND EXAMPLE
  $USER1$/check_ncpa.py -H $HOSTADDRESS$ -t $ARG1$ -M 'plugins/check_process_uptime.ps1' -a "ProcessName=$ARG2 WarningHours=$ARG3 CriticalHours=$ARG4"

.NAGIOS XI SERVICE EXAMPLES
  # WARNING-only at 24h
  check_ncpa_process_uptime!YOUR_NCPA_TOKEN!w3wp.exe!24!

  # CRITICAL-only at 36h
  check_ncpa_process_uptime!YOUR_NCPA_TOKEN!w3wp.exe!!36

  # WARNING=24h, CRITICAL=36h
  check_ncpa_process_uptime!YOUR_NCPA_TOKEN!w3wp.exe!24!36

.RETURN CODES
  0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
#>


param(
    [Parameter(Mandatory = $true)]
    [string]$ProcessName,        # e.g., 'w3wp' or 'w3wp.exe'

    [double]$WarningHours,       # OPTIONAL: WARNING threshold in hours

    [double]$CriticalHours       # OPTIONAL: CRITICAL threshold in hours
)

# Gather matching processes (case-insensitive)
$procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name.Equals($ProcessName, [System.StringComparison]::OrdinalIgnoreCase) }

if (-not $procs) {
    Write-Output "UNKNOWN: Process '$ProcessName' not found"
    exit 3
}

# Helper: try to resolve a start time for a given Win32_Process instance
function Get-StartTime {
    param([object]$proc)

    # 1) Try WMI/CIM CreationDate (DMTF format)
    $dmtf = $proc.CreationDate
    if ($dmtf -and $dmtf.Length -ge 25) {
        try {
            return [System.Management.ManagementDateTimeConverter]::ToDateTime($dmtf)
        } catch {
            # fall through to Get-Process
        }
    }

    # 2) Fallback to Get-Process StartTime (can throw for protected processes)
    try {
        $gp = Get-Process -Id $proc.ProcessId -ErrorAction Stop
        return $gp.StartTime
    } catch {
        return $null
    }
}

# Build instances with valid start times
$instances = foreach ($p in $procs) {
    $start = Get-StartTime -proc $p
    if ($null -ne $start) {
        [PSCustomObject]@{
            Name        = $p.Name
            ProcessId   = $p.ProcessId
            StartTime   = $start
            UptimeHours = (New-TimeSpan -Start $start -End (Get-Date)).TotalHours
        }
    }
}

# If none of the instances expose a readable start time, we cannot compute uptime
if (-not $instances -or $instances.Count -eq 0) {
    $count = $procs.Count
    Write-Output "UNKNOWN: Found $count instance(s) of '$ProcessName' but none expose a readable StartTime (permissions or system process)."
    exit 3
}

# Choose the oldest instance
$oldest = $instances | Sort-Object StartTime | Select-Object -First 1
$uptimeRounded = [math]::Round($oldest.UptimeHours, 2)

# Determine Nagios state
$state = "OK"; $code = 0

# Use PSBoundParameters to check whether the caller provided each threshold
$hasWarning  = $PSBoundParameters.ContainsKey('WarningHours')
$hasCritical = $PSBoundParameters.ContainsKey('CriticalHours')

if ($hasCritical -and $oldest.UptimeHours -ge $CriticalHours) {
    $state = "CRITICAL"; $code = 2
}
elseif ($hasWarning -and $oldest.UptimeHours -ge $WarningHours) {
    $state = "WARNING"; $code = 1
}

# Perfdata (empty semicolons if a threshold was not provided)
$warnOut = if ($hasWarning) { $WarningHours } else { "" }
$critOut = if ($hasCritical) { $CriticalHours } else { "" }
$perf = "uptime_hours=$uptimeRounded;$warnOut;$critOut;0;"

# Output (note instance count if multiple)
$extra = if ($instances.Count -gt 1) {
    " (instances=$($instances.Count), oldest PID=$($oldest.ProcessId))"
} else {
    " (PID=$($oldest.ProcessId))"
}

# Brace $state before the colon to avoid parser confusion
Write-Output "${state}: '$ProcessName' uptime=$uptimeRounded h; started $($oldest.StartTime)$extra | $perf"
exit $code
