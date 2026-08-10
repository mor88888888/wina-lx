#!/bin/bash

# Check if regripper is installed
if ! command -v regripper >/dev/null 2>&1; then
    echo "ERROR: RegRipper no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Check if evtx_dump is installed
if ! command -v evtx_dump >/dev/null 2>&1; then
    echo "ERROR: evtx_dump no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Pre-initial
computername=$(regripper -r REG/SYSTEM -p compname 2>/dev/null | grep -i "ComputerName" -A 1 | tail -1 | awk '{print $NF}')

# Declare paths
per_dir=$computername/persistence
exec_dir=$computername/execution
fs_dir=$computername/filesystem
init_dir=$computername/initial
#web_dir=$computername/web
logs_dir=$computername/logs

# Create dirs
mkdir $computername
mkdir $init_dir
mkdir $per_dir
mkdir $exec_dir
mkdir $fs_dir
#mkdir $web_dir
mkdir $logs_dir

# SAM
regripper -r REG/SAM -p samparse > $init_dir/sam-users.txt

# SYSTEM
## Initial
echo $computername > $init_dir/compname.txt
regripper -r REG/SYSTEM -p timezone > $init_dir/timezone.txt
regripper -r REG/SYSTEM -p shutdown > $init_dir/shutdown.txt 
## Persistence
regripper -r REG/SYSTEM -p services > $per_dir/services.txt
## Execution
regripper -r REG/SYSTEM -p shimcache > $exec_dir/shimcache.txt
regripper -r REG/SYSTEM -p bam > $exec_dir/bam.txt
regripper -r REG/SYSTEM -p dam > $exec_dir/dam.txt
## Filesystem
regripper -r REG/SYSTEM -p usb > $fs_dir/usb.txt
regripper -r REG/SYSTEM -p mountdev > $fs_dir/mount.txt
# Find Executables embbebed
regripper -r REG/SYSTEM -p findexes > $per_dir/findexes-system.txt
regripper -r REG/SYSTEM -p sizes > $per_dir/sizes-system.txt

# SOFTWARE
## Initial
regripper -r REG/SOFTWARE -p lastloggedon > $init_dir/lastloggedon.txt
## Persistence
regripper -r REG/SOFTWARE -p run > $per_dir/run-software.txt
regripper -r REG/SOFTWARE -p runonceex > $per_dir/runonceex-software.txt
regripper -r REG/SOFTWARE -p tasks > $per_dir/tasks-software.txt
regripper -r REG/SOFTWARE -p taskcache > $per_dir/taskcache-software.txt
regripper -r REG/SOFTWARE -p gpohist > $per_dir/gpo-software.txt
regripper -r REG/SOFTWARE -p uninstall > $per_dir/uninstall-software.txt
## Initial
regripper -r REG/SOFTWARE -p profilelist > $init_dir/users.txt
regripper -r REG/SOFTWARE -p winver > $init_dir/winver.txt
regripper -r REG/SOFTWARE -p pslogging > $init_dir/psconfig.txt
# Find Executables embbebed
regripper -r REG/SOFTWARE -p findexes > $per_dir/findexes-software.txt
regripper -r REG/SOFTWARE -p sizes > $per_dir/sizes-software.txt

# NTUSER.DAT
for ntuser in REG/NTUSER-*.DAT; do
    # Extrae el usuario: NTUSER-admin.DAT -> admin
    user=$(basename "$ntuser")
    user=${user#NTUSER-}
    user=${user%.DAT}

    usrclass="REG/UsrClass-${user}.dat"

    echo "[+] Procesando usuario: $user"

    # Initial
    regripper -r "$ntuser" -p logonstats > "$init_dir/logonstats-${user}.txt"

    # Persistence
    regripper -r "$ntuser" -p run > "$per_dir/run-${user}.txt"
    regripper -r "$ntuser" -p runonceex > "$per_dir/runonceex-${user}.txt"
    regripper -r "$ntuser" -p tasks > "$per_dir/tasks-${user}.txt"
    regripper -r "$ntuser" -p gpohist > "$per_dir/gpo-${user}.txt"
    regripper -r "$ntuser" -p uninstall > "$per_dir/uninstall-${user}.txt"
    regripper -r "$ntuser" -p appkeys > "$per_dir/appkeys-${user}.txt"
    regripper -r "$ntuser" -p listsoft > "$per_dir/listsoft-${user}.txt"
    regripper -r "$ntuser" -p recentapps > "$per_dir/recentapps-${user}.txt"

    # Filesystem
    regripper -r "$ntuser" -p typedurls > "$fs_dir/typedurls-${user}.txt"
    regripper -r "$ntuser" -p typedpaths > "$fs_dir/typedpaths-${user}.txt"
    regripper -r "$ntuser" -p recentdocs > "$fs_dir/recentdocs-${user}.txt"
    regripper -r "$ntuser" -p winrar > "$fs_dir/winrar-${user}.txt"
    regripper -r "$ntuser" -p sevenzip > "$fs_dir/7zip-${user}.txt"
    regripper -r "$ntuser" -p mmc > "$fs_dir/mmc-${user}.txt"

    # Execution
    regripper -r "$ntuser" -p userassist > "$exec_dir/userassist-${user}.txt"
    regripper -r "$ntuser" -p jumplistdata > "$exec_dir/jumplist-${user}.txt"
    regripper -r "$ntuser" -p runmru > "$exec_dir/mru-${user}.txt"
    regripper -r "$ntuser" -p muicache > "$exec_dir/muicache-ntuser-${user}.txt"
    regripper -r "$ntuser" -p advanced_ip_scanner > "$exec_dir/ad-ip-scanner-${user}.txt"

    # UsrClass asociado
    if [[ -f "$usrclass" ]]; then
        regripper -r "$usrclass" -p shellbags > "$exec_dir/shellbags-${user}.txt"
        regripper -r "$usrclass" -p muicache > "$exec_dir/muicache-usrclass-${user}.txt"
    fi

    # Find Executables embedded
    regripper -r "$ntuser" -p findexes > "$per_dir/findexes-${user}.txt"
    regripper -r "$ntuser" -p sizes > "$per_dir/sizes-${user}.txt"

done

# AMCACHE
regripper -r REG/Amcache.hve -p amcache > $exec_dir/amcache.txt

# Prefetch - https://github.com/PoorBillionaire/Windows-Prefetch-Parser
regripper -r REG/SYSTEM -p prefetch > $init_dir/prefetch-config.txt
#python3 prefetch.py -f FS/*.pf -c $exec_dir/prefetch.csv

# MFT (pip3 install analyzeMFT)
analyzeMFT -f 'C/$MFT' -o $fs_dir/mft.csv --csv

# EVTX - https://github.com/omerbenamram/evtx
evtx_dump EVTX/Security.evtx -o jsonl -f $logs_dir/security.json
evtx_dump EVTX/System.evtx -o jsonl -f $logs_dir/system.json
evtx_dump EVTX/Windows\ PowerShell.evtx -o jsonl -f $logs_dir/ps.json
evtx_dump "EVTX/Microsoft-Windows-PowerShell%4Operational.evtx" -o jsonl -f $logs_dir/ps-op.json

# LNKs - https://github.com/Matmaus/LnkParse3
#> $fs_dir/lnk.csv

# Web Browsers - https://github.com/RyanDFIR/hindsight/
#> $web_dir/chrome
#> $web_dir/edge
#> $web_dir/firefox

# TASKS (xml)
# > $per_dir/tasks.txt
