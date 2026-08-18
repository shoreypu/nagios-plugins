# check_selinux_status

Nagios plugin that verifies a system's SELinux status matches an administrator-defined expected state.

The plugin compares the current SELinux mode reported by `getenforce` against the configured expectation and returns standard Nagios status codes based on the severity of any mismatch.

## Features

- Verifies SELinux state is Enforcing, Permissive, or Disabled
- Compares current state against an expected state
- Returns standard Nagios plugin status codes
- Supports security and compliance monitoring
- Handles invalid or unavailable SELinux status information
- Lightweight Bash implementation

## Requirements

- Bash
- SELinux utilities (`getenforce`)

## Usage

```bash
check_selinux_status.sh -s <state>
```

## Options

| Option | Description |
|----------|-------------|
| `-s` | Expected SELinux state (`enforcing`, `permissive`, or `disabled`) |
| `-h` | Display help |

## Examples

### Verify SELinux is Enforcing

```bash
check_selinux_status.sh -s enforcing
```

### Verify SELinux is Permissive

```bash
check_selinux_status.sh -s permissive
```

### Verify SELinux is Disabled

```bash
check_selinux_status.sh -s disabled
```

## Example Output

### OK

```text
OK: SELinux is Enforcing (as expected)
```

### WARNING

```text
WARNING: SELinux is Permissive (expected Enforcing)
```

### CRITICAL

```text
CRITICAL: SELinux is Disabled (expected Enforcing)
```

### UNKNOWN

```text
UNKNOWN: getenforce not available or returned empty
```

## Status Logic

When the current SELinux state matches the expected state:

- OK

When the state differs:

| Expected State | Actual State | Result |
|---------------|-------------|---------|
| Enforcing | Permissive | WARNING |
| Enforcing | Disabled | CRITICAL |
| Permissive | Enforcing | WARNING |
| Permissive | Disabled | CRITICAL |
| Disabled | Permissive | WARNING |
| Disabled | Enforcing | CRITICAL |

## Use Cases

- Security compliance monitoring
- Baseline configuration validation
- Alerting on unauthorized SELinux changes
- Monitoring hardened Linux systems
- Verifying server build standards

## License

GPLv3
