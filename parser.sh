#!/bin/bash

SCRIPT_DIR=$(dirname $0)

regripper="perl ${SCRIPT_DIR}/bin/RegRipper4.0/rip.pl"
evtx_dump="${SCRIPT_DIR}/bin/evtx_dump"
hindsight="${SCRIPT_DIR}/bin/hindsight"

# Check if regripper is installed ()
if ! command -v $regripper >/dev/null 2>&1; then
    echo "[ERROR] RegRipper no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Check if evtx_dump is installed (https://github.com/omerbenamram/evtx)
if ! command -v $evtx_dump >/dev/null 2>&1; then
    echo "[ERROR] evtx_dump no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Check if lnkparse is installed (https://github.com/RyanDFIR/hindsight/)
if ! command -v $hindsight >/dev/null 2>&1; then
    echo "[ERROR] Hindsight no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Check if analyzemft is installed (https://github.com/rowingdude/analyzeMFT - pip3 install analyzeMFT)
if ! command -v analyzemft >/dev/null 2>&1; then
    echo "[ERROR] analyzeMFT no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Check if lnkparse is installed (https://github.com/Matmaus/LnkParse3 - pip3 install LnkParse3)
if ! command -v lnkparse >/dev/null 2>&1; then
    echo "[ERROR] LNKParser3 no está instalado o no se encuentra en el PATH."
    exit 1
fi

# Declare input/output paths
root_dir="${1%/}"
output_dir="${2%/}"

# Validar que no estén vacíos
if [ -z "$root_dir" ] || [ -z "$output_dir" ]; then
    echo "[INFO] Uso: sh $0 <root_dir> <output_dir>"
    exit 1
fi

if [[ ! -d "${root_dir}" ]]; then
	echo "[ERROR] No existe el path de entrada '${root_dir}'"
    exit 1
fi

if [[ ! -d "${output_dir}" ]]; then
	echo "[ERROR] No existe el path de salida: '${output_dir}'"
    exit 1
fi

# Find artifacts
SAM=$root_dir/Windows/System32/config/SAM
SYSTEM=$root_dir/Windows/System32/config/SYSTEM
SOFTWARE=$root_dir/Windows/System32/config/SOFTWARE
AMCACHE=$root_dir/Windows/appcompat/Programs/Amcache.hve
MFT=$root_dir/'$MFT'
#PREF=$root_dir/Windows/Prefetch
LOG_SEC=$root_dir/Windows/System32/winevt/Logs/Security.evtx
LOG_SYS=$root_dir/Windows/System32/winevt/Logs/System.evtx
LOG_PWSH="${root_dir}/Windows/System32/winevt/Logs/Windows PowerShell.evtx"
LOG_PWOP="$root_dir/Windows/System32/winevt/Logs/Microsoft-Windows-PowerShell%4Operational.evtx"
LNK_STARTS="${root_dir}/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp"
TASKS=$root_dir/Windows/System32/Tasks

# Corrige un path usando comparaciones case-insensitive
resolve_case_path() {
    local path="$1"
    local current=""
    local component=""
    local match=""
 
    # Mantener path absoluto o relativo
    if [[ "$path" == /* ]]; then
        current="/"
        path="${path#/}"
    fi
 
    IFS='/' read -ra parts <<< "$path"
 
    for component in "${parts[@]}"; do
        [[ -z "$component" ]] && continue
 
        match=$(find "$current" -maxdepth 1 -mindepth 1 \
            -iname "$component" \
            -printf '%f\n' 2>/dev/null | head -n1)
 
        if [[ -n "$match" ]]; then
            current="${current%/}/$match"
        else
            # Si no existe, devolver el original
            echo "$1"
            return 1
        fi
    done
 
    echo "$current"
}

# Test regripper and create output folder
computername=$($regripper -r $SYSTEM -p compname 2>/dev/null | grep -i "ComputerName" -A 1 | tail -1 | awk '{print $NF}');

if [[ -z "$computername" ]]; then
    echo "[ERROR] No se pudo obtener el nombre del equipo del SYSTEM hive. Verifica que: $SYSTEM exista"
    exit 1
fi

echo "[INFO] Equipo a analizar: $computername"
mkdir -p "$output_dir/$computername"

# Check and correct input paths
paths=(
    SAM
    SYSTEM
    SOFTWARE
    AMCACHE
    MFT
    #PREF
    LOG_SEC
    LOG_SYS
    LOG_PWSH
    LOG_PWOP
    LNK_STARTS
    TASKS
)
 
for var in "${paths[@]}"; do
    corrected=$(resolve_case_path "${!var}")
 
    if [[ $? -eq 0 ]]; then
        printf -v "$var" '%s' "$corrected"
    else
        echo "[WARN] No encontrado: ${!var}" >>"$output_dir/${computername}-log.txt"
    fi
done

# Create output dir structure
init_dir=$output_dir/$computername/initial; mkdir $init_dir
per_dir=$output_dir/$computername/persistence; mkdir $per_dir
exec_dir=$output_dir/$computername/execution; mkdir $exec_dir
fs_dir=$output_dir/$computername/filesystem; mkdir $fs_dir
web_dir=$output_dir/$computername/web; mkdir $web_dir
logs_dir=$output_dir/$computername/logs; mkdir $logs_dir
tasks_dir=$per_dir/Tasks; mkdir $tasks_dir

# SAM
echo "[INFO] Procesando SAM"
$regripper -r $SAM -p samparse > $init_dir/sam-users.txt 2>>"$output_dir/${computername}-log.txt"

# SYSTEM
echo "[INFO] Procesando SYSTEM"
## Initial
echo $computername > $init_dir/compname.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SYSTEM -p timezone > $init_dir/timezone.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SYSTEM -p shutdown > $init_dir/shutdown.txt 2>>"$output_dir/${computername}-log.txt" 
## Persistence
$regripper -r $SYSTEM -p services > $per_dir/services.txt 2>>"$output_dir/${computername}-log.txt"
## Execution
$regripper -r $SYSTEM -p shimcache > $exec_dir/shimcache.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SYSTEM -p bam > $exec_dir/bam.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SYSTEM -p dam > $exec_dir/dam.txt 2>>"$output_dir/${computername}-log.txt"
## Filesystem
$regripper -r $SYSTEM -p usb > $fs_dir/usb.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SYSTEM -p mountdev > $fs_dir/mount.txt 2>>"$output_dir/${computername}-log.txt"
# Find Executables embbebed
$regripper -r $SYSTEM -p findexes > $per_dir/findexes-system.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SYSTEM -p sizes > $per_dir/sizes-system.txt 2>>"$output_dir/${computername}-log.txt"

# SOFTWARE
echo "[INFO] Procesando SOFTWARE"
## Initial
$regripper -r $SOFTWARE -p lastloggedon > $init_dir/lastloggedon.txt 2>>"$output_dir/${computername}-log.txt"
## Persistence
$regripper -r $SOFTWARE -p run > $per_dir/run-software.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p runonceex > $per_dir/runonceex-software.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p tasks > $per_dir/tasks-software.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p taskcache > $per_dir/taskcache-software.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p gpohist > $per_dir/gpo-software.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p uninstall > $per_dir/uninstall-software.txt 2>>"$output_dir/${computername}-log.txt"
## Initial
$regripper -r $SOFTWARE -p profilelist > $init_dir/users.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p winver > $init_dir/winver.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p pslogging > $init_dir/psconfig.txt 2>>"$output_dir/${computername}-log.txt"
# Find Executables embbebed
$regripper -r $SOFTWARE -p findexes > $per_dir/findexes-software.txt 2>>"$output_dir/${computername}-log.txt"
$regripper -r $SOFTWARE -p sizes > $per_dir/sizes-software.txt 2>>"$output_dir/${computername}-log.txt"

# AMCACHE
echo "[INFO] Procesando AMCACHE"
if [ -f $AMCACHE ]; then
	$regripper -r $AMCACHE -p amcache > $exec_dir/amcache.txt 2>>"$output_dir/${computername}-log.txt"
else
	echo "[WARN] ${AMCACHE} not found"
fi

# Prefetch
echo "[INFO] Procesando PREFETCH"
$regripper -r $SYSTEM -p prefetch > $init_dir/prefetch-config.txt 2>>"$output_dir/${computername}-log.txt"

#if [ -d $PREF ]; then
#	???
#else
#	echo "[WARN] ${PREF} not found"
#fi

# MFT
echo "[INFO] Procesando MFT"
if [ -f $AMCACHE ]; then
	analyzemft -f $MFT -o $fs_dir/mft.csv --csv 2>>"$output_dir/${computername}-mft-log.txt"
else
	echo "[WARN] ${MFT} not found"
fi

# EVTX
echo "[INFO] Procesando EVTX"
if [ -f $LOG_SEC ]; then
	$evtx_dump $LOG_SEC -o jsonl -f $logs_dir/security.json 2>>"$output_dir/${computername}-log.txt"
else
	echo "[WARN] ${LOG_SEC} not found"
fi

if [ -f $LOG_SYS ]; then
	$evtx_dump $LOG_SYS -o jsonl -f $logs_dir/system.json 2>>"$output_dir/${computername}-log.txt"
else
	echo "[WARN] ${LOG_SYS} not found"
fi

if [ -f "$LOG_PWSH" ]; then
	$evtx_dump "$LOG_PWSH" -o jsonl -f $logs_dir/ps.json 2>>"$output_dir/${computername}-log.txt"
else
	echo "[WARN] ${LOG_PWSH} not found"
fi

if [ -f $LOG_PWOP ]; then
	$evtx_dump $LOG_PWOP -o jsonl -f $logs_dir/ps-op.json 2>>"$output_dir/${computername}-log.txt"
else
	echo "[WARN] ${LOG_PWOP} not found"
fi

# TASKS
echo "[INFO] Procesando Tareas"
# Verificar que el directorio existe
if [ -d "$TASKS" ]; then
    cp -r $TASKS $tasks_dir
else
	echo "[WARN]: El directorio $TASKS no existe"
fi

# LNKs
echo "[INFO] Procesando LNKs"
# Verificar que el directorio existe
if [ ! -d "$LNK_STARTS" ]; then
    echo "[WARN] $LNK_STARTS not found"
fi

for file in "$LNK_STARTS"/*.lnk; do
    # Saltar si no hay archivos .lnk (el patrón no coincide)
    [ -e "$file" ] || continue
    
    # Ejecutar lnkparse sobre el archivo
    echo "Procesando: $file" >>"$output_dir/${computername}-log.txt"
    lnkparse -t "$file" >> $per_dir/startup-lnk-targets.txt
done


# NTUSER.DAT
if [ -d "$root_dir/Users" ]; then
	for userfolder in "$root_dir/Users/"* ; do
		user=$(basename "$userfolder")
		echo "[INFO] Procesando usuario: $user"
		
		# Find user artifacts
		NTUSERDAT=$userfolder/NTUSER.DAT
		USRCLASS=$userfolder/AppData/Local/Microsoft/Windows/usrClass.dat
		EDGE=$userfolder/AppData/Local/Microsoft/Edge/User\ Data
		CHROME=$userfolder/AppData/Local/Google/Chrome/User\ Data
		FIREFOX=$userfolder/AppData/Roaming/Mozilla/Firefox/Profiles
		LNK_RECENT=$userfolder/AppData/Roaming/Microsoft/Windows/Recent
		LNK_OFFICE=$userfolder/AppData/Roaming/Microsoft/Office/Recent
		LNK_DESKTP=$userfolder/Desktop
		LNK_STARTU=$userfolder/AppData/Roaming/Microsoft/Windows/Start\ Menu/Programs/Startup
		
		paths=(
		    NTUSERDAT
		    USRCLASS
		    EDGE
		    CHROME
		    FIREFOX
		    LNK_RECENT
		    LNK_OFFICE
		    LNK_DESKTP
		    LNK_STARTU
		)
		
		for var in "${paths[@]}"; do
		    corrected=$(resolve_case_path "${!var}")
		 
		    if [[ $? -eq 0 ]]; then
		        printf -v "$var" '%s' "$corrected"
		    else
		        echo "[WARN] No encontrado: ${!var}" >>"$output_dir/${computername}-log.txt"
		    fi
		done

		# Create folder structure
		mkdir -p $init_dir/user/$user
		mkdir -p $per_dir/user/$user
		mkdir -p $exec_dir/user/$user
		mkdir -p $fs_dir/user/$user
		mkdir -p $web_dir/user/$user
		
		if [ -f $NTUSERDAT ]; then
		    # Initial
		    $regripper -r $NTUSERDAT -p logonstats > "$init_dir/user/${user}/logonstats.txt" 2>>"$output_dir/${computername}-log.txt"

		    # Persistence
		    $regripper -r $NTUSERDAT -p run > "$per_dir/user/${user}/run.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p runonceex > "$per_dir/user/${user}/runonceex.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p tasks > "$per_dir/user/${user}/tasks.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p gpohist > "$per_dir/user/${user}/gpo.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p uninstall > "$per_dir/user/${user}/uninstall.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p appkeys > "$per_dir/user/${user}/appkeys.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p listsoft > "$per_dir/user/${user}/listsoft.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p recentapps > "$per_dir/user/${user}/recentapps.txt" 2>>"$output_dir/${computername}-log.txt"

		    # Filesystem
		    $regripper -r $NTUSERDAT -p typedurls > "$fs_dir/user/${user}/typedurls.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p typedpaths > "$fs_dir/user/${user}/typedpaths.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p recentdocs > "$fs_dir/user/${user}/recentdocs.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p winrar > "$fs_dir/user/${user}/winrar.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p sevenzip > "$fs_dir/user/${user}/7zip.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p mmc > "$fs_dir/user/${user}/mmc.txt" 2>>"$output_dir/${computername}-log.txt"

		    # Execution
		    $regripper -r $NTUSERDAT -p userassist > "$exec_dir/user/${user}/userassist.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p jumplistdata > "$exec_dir/user/${user}/jumplist.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p runmru > "$exec_dir/user/${user}/mru.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p muicache > "$exec_dir/user/${user}/muicache-ntuser.txt" 2>>"$output_dir/${computername}-log.txt"

		    # Find Executables embedded
		    $regripper -r $NTUSERDAT -p findexes > "$per_dir/user/${user}/findexes.txt" 2>>"$output_dir/${computername}-log.txt"
		    $regripper -r $NTUSERDAT -p sizes > "$per_dir/user/${user}/sizes.txt" 2>>"$output_dir/${computername}-log.txt"
		else
			echo "[WARN] ${NTUSERDAT} not found"
		fi

	    # UsrClass asociado
	    if [ -f $USRCLASS ]; then
	        $regripper -r $USRCLASS -p shellbags > "$exec_dir/user/${user}/shellbags.txt" 2>>"$output_dir/${computername}-log.txt"
	        $regripper -r $USRCLASS -p muicache > "$exec_dir/user/${user}/muicache-usrclass.txt" 2>>"$output_dir/${computername}-log.txt"
	    else
			echo "[WARN] ${USRCLASS} not found"
	    fi
		
		# LNKs
		
		## Automatically created LNK on files access:
		# C:\Users\%USERNAME%\AppData\Roaming\Microsoft\Windows\Recent\*.lnk
		for file in "$LNK_RECENT"/*.lnk; do
		    # Saltar si no hay archivos .lnk (el patrón no coincide)
		    [ -e "$file" ] || continue
		    
		    # Ejecutar lnkparse sobre el archivo
		    echo "Procesando: $file" >>"$output_dir/${computername}-log.txt"
		    lnkparse -t "$file" >> "$fs_dir/user/${user}/recent-lnk-targets.txt"
		done
		
		## Automatically created LNK for documents opened using Microsoft Office products:
		# C:\Users\%USERNAME%\AppData\Roaming\Microsoft\Office\Recent\*.lnk
		for file in "$LNK_OFFICE"/*.lnk; do
		    # Saltar si no hay archivos .lnk (el patrón no coincide)
		    [ -e "$file" ] || continue
		    
		    # Ejecutar lnkparse sobre el archivo
		    echo "Procesando: $file" >>"$output_dir/${computername}-log.txt"
		    lnkparse -t "$file" >> "$fs_dir/user/${user}/office-lnk-targets.txt"
		done
	    
	    ## Users Desktop folder:
		# C:\Users\%USERNAME%\Desktop\*.lnk
		for file in "$LNK_DESKTP"/*.lnk; do
		    # Saltar si no hay archivos .lnk (el patrón no coincide)
		    [ -e "$file" ] || continue
		    
		    # Ejecutar lnkparse sobre el archivo
		    echo "Procesando: $file" >>"$output_dir/${computername}-log.txt"
		    lnkparse -t "$file" >> "$fs_dir/user/${user}/desktop-lnk-targets.txt"
		done
		
		## Startup folders:
		# C:\Users\%USERNAME%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk
		for file in "$LNK_STARTU"/*.lnk; do
		    # Saltar si no hay archivos .lnk (el patrón no coincide)
		    [ -e "$file" ] || continue
		    
		    # Ejecutar lnkparse sobre el archivo
		    echo "Procesando: $file" >>"$output_dir/${computername}-log.txt"
		    lnkparse -t "$file" >> "$fs_dir/user/${user}/startup-lnk-targets.txt"
		done
		
		# Web Browsers
		if [ -d "$EDGE" ]; then
		    $hindsight -i "$EDGE" -o "$web_dir/user/${user}/edge" -l "$output_dir/${computername}-hindsight-log.txt" >/dev/null 2>&1
		else
			echo "[WARN]: El directorio $EDGE no existe" >>"$output_dir/${computername}-log.txt"
		fi
		
		if [ -d "$CHROME" ]; then
		    $hindsight -i "$CHROME" -o "$web_dir/user/${user}/chrome" -l "$output_dir/${computername}-hindsight-log.txt" >/dev/null 2>&1
		else
			echo "[WARN]: El directorio $CHROME no existe" >>"$output_dir/${computername}-log.txt"
		fi
		
		if [ -d "$FIREFOX" ]; then
		    $hindsight -i "$FIREFOX" -o "$web_dir/user/${user}/firefox" -l "$output_dir/${computername}-hindsight-log.txt" >/dev/null 2>&1
		else
			echo "[WARN]: El directorio $FIREFOX no existe" >>"$output_dir/${computername}-log.txt"
		fi
  
	done
fi