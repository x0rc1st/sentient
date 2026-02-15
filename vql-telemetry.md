# VQL Telemetry Enhancement Plan

## Current Stack
- Velociraptor agent (Windows + Linux)
- Sysmon (Windows only)

## Built Into Velociraptor (No Deployment Needed)

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

### USN Journal Monitoring
- VQL plugin: `watch_usn()`
- Real-time NTFS file system change tracking (file creates, deletes, renames, modifications)
- Catches file activity that Sysmon FileCreate (Event ID 11) might miss

### Process Memory Analysis
- VQL plugins: `proc_dump()`, `vad()`, `proc_yara()`
- Read and scan process memory directly — partial replacement for Volatility
- Combine with YARA for in-memory malware detection without a separate memory forensics tool

### Forensic Artifact Parsing
- **Prefetch** — execution history (`Windows.Forensics.Prefetch`)
- **Shimcache/Amcache** — program execution evidence (`Windows.Registry.AppCompatCache`, `Windows.Detection.Amcache`)
- **SRUM** — network usage, app resource usage (`Windows.Forensics.SRUM`)
- All parseable natively in VQL, no external tools

### Network Packet Capture
- VQL plugin: `pcap()`
- Capture network traffic directly from the endpoint
- Useful for short targeted captures during incident response

### WMI Event Subscriptions
- VQL plugin: `wmi_events()`
- Monitor for WMI-based persistence (a common attacker technique)

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

### Suricata
- Network IDS/IPS
- VQL can parse its `eve.json` output for alert-based network detections
- Complements endpoint telemetry with network-layer signature matching

### Zeek
- Network security monitor
- VQL can parse Zeek logs (conn.log, dns.log, http.log, etc.)
- Provides protocol-level network metadata

### eBPF Tools (Linux)
- Kernel-level tracing, more granular than auditd
- VQL can consume output from eBPF-based tools
- Covers syscalls, network events, file access at the kernel level

## Priority

| Priority | Tool | Deploy? | Visibility Gain |
|----------|------|---------|-----------------|
| 1 | Sigma rules | Rules only (engine built-in) | Detection logic on top of existing Sysmon data |
| 2 | YARA rules | Rules only (engine built-in) | File/memory scanning for malware signatures |
| 3 | ETW providers | Nothing (built-in) | AMSI, PowerShell, DNS, kernel-level events |
| 4 | USN Journal | Nothing (built-in) | Real-time NTFS file system change tracking |
| 5 | Process memory analysis | Nothing (built-in) | In-memory malware detection, partial Volatility replacement |
| 6 | Forensic artifacts | Nothing (built-in) | Prefetch, Shimcache, Amcache, SRUM |
| 7 | Network packet capture | Nothing (built-in) | Targeted endpoint pcap |
| 8 | WMI event subscriptions | Nothing (built-in) | WMI persistence detection |
| 9 | OSQuery | Binary | ~300 additional queryable tables |
| 10 | Auditd | Package (Linux) | Syscall-level visibility on Linux targets |
| 11 | Suricata | Package | Network IDS alert-based detections |
| 12 | Zeek | Package | Protocol-level network metadata |
| 13 | eBPF tools | Package (Linux) | Kernel-level tracing beyond auditd |
