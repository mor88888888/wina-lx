# Windows Forensic Artifact Collector

A Bash automation script for systematic digital forensic evidence collection from Windows systems. This script orchestrates multiple forensic tools to extract, parse, and organize artifacts into categorized output directories.

[![Licencia](https://img.shields.io/github/license/mor88888888/cntlm-wizard-for-linux?style=flat-square)](LICENSE) [![Linux](https://img.shields.io/badge/Platform-Linux-blue?style=flat-square&logo=linux)]() 

## Overview

This tool automates the collection of key Windows forensic artifacts including:

- **Registry Hives**: SAM, SYSTEM, SOFTWARE, AMCACHE, NTUSER.DAT

- **Event Logs**: Security, System, Windows PowerShell (classic and operational)

- **Filesystem Artifacts**: MFT, Prefetch, LNK files, Scheduled Tasks

- **User-Specific Artifacts**: Browser data, Recent documents, Run MRU, UserAssist

## Prerequisites

Ensure the following tools are installed and accessible in your PATH:

| Tool         | Purpose                                | Repository                                                |
| ------------ | -------------------------------------- | --------------------------------------------------------- |
| `rip.pl`     | Registry hive analysis (RegRipper 4.0) | [RegRipper](https://github.com/keydet89/RegRipper3.0)     |
| `evtx_dump`  | Windows Event Log parsing              | [EVTX-MSG-PARSER](https://github.com/omerbenamram/evtx)   |
| `analyzemft` | MFT record extraction                  | [analyzeMFT](https://github.com/teamdfir/AnalyzingTheMFT) |

## Usage

```bash
sh windows-forensic-collector.sh <root_directory> <output_directory>
```

Output structure:

```
<output_directory>/<computername>/
├── initial/           # System baseline (hostname, users, timezone, last logon)
├── persistence/       # Persistence mechanisms (services, run keys, tasks, uninstall)
├── execution/         # Execution trails (UserAssist, ShimCache, BAM, DAM)
├── filesystem/        # Filesystem artifacts (USB devices, mounted volumes, typed URLs)
├── web/              # Browser artifacts (Chrome, Edge, Firefox)
└── logs/             # Parsed event logs (Security, System, PowerShell)
```

## Notes

- Case-insensitive path resolution is performed automatically
- Warnings for missing artifacts are logged to `<computername>-log.txt`
- Each operation appends errors to `<computername>-log.txt` for audit purposes
- Browser artifact parsing (Hindsight, etc.) requires additional setup (commented in script)

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the LICENSE file for details.
