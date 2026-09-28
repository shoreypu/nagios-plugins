# check_iis_apppools

Nagios XI / NCPA plugin that checks IIS Application Pool states using PowerShell's `WebAdministration` module. It can check all pools or a requested subset. The check is read-only and does not start or stop pools.

## Features

- Checks all application pools or selected pools
- Reports stopped pools and requested pools that do not exist as CRITICAL
- Reports transitional and other unexpected states as WARNING
- Returns Nagios-compatible status codes
- Provides performance data for graphing
- Supports Nagios XI through NCPA

## Requirements

- Windows Server with IIS installed
- PowerShell and the IIS `WebAdministration` module
- NCPA Agent for remote execution
- NCPA service account with permission to query IIS

## Usage

Run locally in PowerShell:

```powershell
.\check_iis_apppools.ps1
.\check_iis_apppools.ps1 All
.\check_iis_apppools.ps1 "DefaultAppPool"
.\check_iis_apppools.ps1 "AppPool1,AppPool2"
