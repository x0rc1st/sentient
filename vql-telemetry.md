# VQL Telemetry Enhancement Plan

## Current Stack
- Velociraptor agent (Windows + Linux)
- Sysmon (Windows only)

## Built Into Velociraptor (Rules Only)

### YARA
- YARA engine is compiled into the Velociraptor binary
- VQL plugin: `yara()`
- Artifacts: `Windows.Detection.Yara.NTFS`, `Generic.Detection.Yara.Glob`
- Scan memory of running processes and files on disk (including locked files via NTFS raw access)
- Can be triggered as client events for continuous monitoring
- Only need to supply `.yar` rule files

### Sigma
- Sigma rule compiler is built into Velociraptor
- VQL plugin: `sigma()`
- Compiles Sigma YAML rules into VQL queries at runtime
- No need for `sigmac`, `pySigma`, or any external tooling
- Layers detection logic on top of existing Sysmon data
- Only need to supply `.yml` Sigma rule files

### ETW (Event Tracing for Windows)
- Velociraptor subscribes to raw ETW providers via VQL using `watch_etw()`
- Provides visibility beyond what Sysmon covers
- Useful providers:
  - `Microsoft-Windows-Kernel-Process`
  - `Microsoft-Windows-Kernel-File`
  - `Microsoft-Windows-DNS-Client`
  - `Microsoft-Windows-PowerShell`
  - `Microsoft-Antimalware-Scan-Interface` (AMSI)

## Requires Deployment (Queryable via VQL)

### OSQuery
- VQL plugin: `osquery()`
- Deploy `osqueryd` binary to targets
- Gives access to ~300 queryable tables covering:
  - Installed programs, services, scheduled tasks
  - Open ports, active connections, listening sockets
  - User accounts, groups, logged-in users
  - Hardware info, disk encryption status
  - Browser extensions, Chrome/Firefox history

### Auditd (Linux)
- Linux equivalent of Sysmon
- Velociraptor parses auditd logs via VQL
- Configure audit rules for:
  - Syscall monitoring (execve, connect, open)
  - File integrity monitoring
  - User/group changes

### Autoruns / SysInternals
- Deploy `autorunsc.exe` to targets
- Artifact: `Windows.Sysinternals.Autoruns`
- Comprehensive persistence enumeration beyond registry VQL queries

## Priority

| Priority | Tool | Deploy? | Visibility Gain |
|----------|------|---------|-----------------|
| 1 | Sigma rules | Rules only (engine built-in) | Detection logic on top of existing Sysmon data |
| 2 | YARA rules | Rules only (engine built-in) | File/memory scanning for malware signatures |
| 3 | ETW providers | Nothing (built-in) | AMSI, PowerShell, DNS, kernel-level events |
| 4 | OSQuery | Binary | ~300 additional queryable tables |
| 5 | Auditd | Package (Linux) | Syscall-level visibility on Linux targets |
