# nagios-plugins

A collection of custom Nagios and monitoring plugins developed for infrastructure, systems, application, and operational monitoring.

These plugins are designed to extend monitoring capabilities across a variety of platforms and services, including Linux, Windows, network devices, applications, and monitoring infrastructure.

## Available Plugins

### check_chrony_primary
Verifies that Chrony has selected a primary NTP source and validates offset and optional jitter thresholds.

### check_chrony_tracking
Validates Chrony synchronization health using chronyc tracking.

### check_selinux_status
Verifies a system's SELinux status matches an administrator-defined expected state.
 
## Future Plugins
### collect_palo_natpools.py
### collect_palo_cps.py
### collect_palo_dos.py
### check_iis_apppools.ps1
### check_dsml.pl (Primary Only - Directory Service Markup Language)
### check_ffmpeg.sh
### check_logrotate_nagios_multi_rhel.sh
### check_papercut_status
### check_selinux_auditd_rotation.sh
### disablenotifications_host.sh
### disablenotifications_service.sh
### enablenotifications.sh
### pu_check_curl.php (Primary Only)
### pu_check_generic (Primary Only)
### pu_check_https_aws_duo (Primary Only)
### pu_check_netid_ws.pl (Primary Only)
### pu-check-website
### pu-check-website-test (Primary Only)
### pu_check_wso2_api.sh (Primary Only)
### pu-notify-all-emails
