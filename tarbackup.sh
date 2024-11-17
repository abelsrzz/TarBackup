#!/bin/bash

backup_path="/root/backups" # Ruta por defecto donde se guardarán las copias de seguridad
backup_datetime=$(date +%Y%m%d%H%M%S) # Fecha y hora actual para nombrar el archivo de respaldo
backup_name="$backup_datetime.tar.gz" # Nombre del archivo de respaldo
backup_directory="/" # Directorio por defecto a respaldar

# Texto en rojo
function RED() {
	echo -e "\e[91m$1\e[0m"
}
# Texto en verde
function GREEN() {
	echo -e "\e[92m$1\e[0m"
}
# Texto en amarillo
function YELLOW() {
	echo -e "\e[93m$1\e[0m"
}

# Función para manejar errores
function error() {
	RED "Error: Se ha interrumpido la ejecución del script."
	if [[ -n $TAR_PID ]]; then
		kill -9 "$TAR_PID" 2>/dev/null
	fi
	exit 1
}

# Manejar la señal SIGINT (Ctrl+C)
trap error SIGINT

# Función para verificar si una ruta es absoluta
function check_path() {
	if [[ ! $1 =~ ^/ ]]; then
		RED "$1 no es una ruta absoluta válida."
		error
	fi
}

# Función para verificar si una ruta existe
function check_path_exists() {
	if [[ ! -d $1 ]]; then
		RED "$1 no existe."
		error
	fi
}

# Función para verificar si el script se está ejecutando como root
function check_root() {
	if [[ $EUID -ne 0 ]]; then
		RED "Este script debe ser ejecutado como root o con privilegios de sudo."
		error
	fi
}

# Función para verificar que el comando tar esté instalado
function check_tar_installed(){
	if ! command -v tar &>/dev/null; then
		RED "tar no está instalado. Por favor, instale tar antes de ejecutar este script."
		error
	fi
}

# Función para solicitar la ruta donde se guardará la copia de seguridad

function get_backup_path(){
	read -p "Seleccione la ruta absoluta donde se guardará la copia [default: $backup_path]: " new_backup_path

	# Si el usuario ingresó una nueva ruta, actualizar la variable backup_path
	if [ -n "$new_backup_path" ]; then
		backup_path="$new_backup_path"
	fi

	# Verificar si la ruta es absoluta
	check_path "$backup_path"

	# Verificar si la ruta existe, si no, crearla
	if [[ -d $backup_path ]]; then
		echo "La ruta $backup_path ya existe."
	else
		echo "Creando la ruta $backup_path..."
		mkdir -p "$backup_path"
	fi

	YELLOW "La copia de seguridad se realizará en $backup_path"
}

# Función para solicitar el directorio a respaldar
function get_backup_directory(){
	# Solicitar al usuario el directorio que desea respaldar
	read -p "Seleccione el directorio que desea respaldar [default: /]: " user_backup_directory

	# Si el usuario ingresó un nuevo directorio, actualizar la variable backup_directory
	if [ -n "$user_backup_directory" ]; then
		backup_directory="$user_backup_directory"
		# Verificar si la ruta es absoluta y si existe
		check_path "$user_backup_directory"
		check_path_exists "$user_backup_directory"
	fi
}

function get_exclude_paths(){
	# Rutas por defecto a excluir del respaldo
	default_exclude_paths=(
		"$backup_path"
		'/proc'
		'/sys'
		'/dev'
		'/run'
		'/mnt'
		'/media'
		'/tmp'
	)

	# Solicitar al usuario las rutas a excluir
	read -p "Indique las rutas que desea excluir separadas por comas [example: /home/tarbackup,/var]: " user_exclude_paths

	# Inicializar el array de rutas a excluir con las rutas por defecto
	excluded_paths_array=("${default_exclude_paths[@]}")

	# Leer las rutas ingresadas por el usuario y agregarlas al array de rutas a excluir
	while IFS=',' read -ra exclude_paths_array; do
		for path in "${exclude_paths_array[@]}"; do
			check_path "$path"
			excluded_paths_array+=("$path ")
		done
	done <<<"$user_exclude_paths"

	YELLOW "Las rutas a excluir son: ${excluded_paths_array[*]}"
}

function build_exclude_options(){
	# Construir las opciones --exclude
	exclude_options=()
	for path in "${excluded_paths_array[@]}"; do
		exclude_options+=("--exclude=$path ")
	done
}

function create_backup_name(){
	# Generar un nombre único para el archivo de respaldo
	if [[ $backup_directory == "/" ]]; then
		backup_id_name="root"
	else
		backup_id_name=$(echo "$backup_directory" | cut -c2- | tr "/" "-")
	fi

	file_name="$backup_path/$backup_id_name-$HOSTNAME-$backup_name"
}

function get_backup_size(){
	# Obtener el tamaño total del directorio en bytes
	YELLOW "Calculando el tamaño total del directorio..."

	if [[ "${exclude_options[*]}" =~ "$backup_directory" ]]; then
		du_command="du -s --block-size=1M $backup_directory 2>/dev/null | cut -f1"
	else
		du_command="du -s --block-size=1M ${exclude_options[*]} $backup_directory 2>/dev/null | cut -f1"
	fi

	TOTAL=$(eval "$du_command")
	GREEN "Tamaño total del directorio: $TOTAL M"

	# Verificar si el directorio está vacío
	if [[ $TOTAL -eq 0 ]]; then
		RED "El directorio $backup_directory está vacío."
		error
	fi
}

function start_compression(){
	tar_command="tar -czpvf $file_name ${exclude_options[*]} --one-file-system $backup_directory --verbose > /var/log/tarbackup.log 2>&1 &"
	eval "$tar_command"

	# Obtener el PID del último comando ejecutado en segundo plano
	TAR_PID=$!
}

function monitor_progress(){
	# Inicializar la barra de progreso
	echo -n "Compresión en progreso: ["
	while kill -0 "$TAR_PID" 2>/dev/null; do
		# Obtener el tamaño del archivo tar creado
		PROGRESO=$(du --block-size=1M "$file_name" 2>/dev/null | cut -f1)
		# Calcular el porcentaje de progreso
		PERCENTAGE=$((PROGRESO * 100 / TOTAL))

		# Calcular la longitud de la barra
		BAR_LENGTH=50
		FILLED_LENGTH=$((BAR_LENGTH * PERCENTAGE / 100))
		UNFILLED_LENGTH=$((BAR_LENGTH - FILLED_LENGTH))

		# Mostrar la barra de progreso
		echo -ne "\rCompresión en progreso: [$(printf "%${FILLED_LENGTH}s" | tr ' ' '#')$(printf "%${UNFILLED_LENGTH}s")] $PROGRESO/$TOTAL MB ($PERCENTAGE%)\r"
		sleep 1
	done
	clear

	# Comprobar si el proceso tar finalizó correctamente
	if wait "$TAR_PID"; then
		# Completar la barra de progreso
		echo -e
		GREEN "\rCompresión finalizada: [##############################] $TOTAL/$TOTAL MB (100%)"
		GREEN "Archivo creado: $file_name"
		file_size=$(du -h "$file_name" | cut -f1)
		YELLOW "El tamaño total del archivo comprimido es: $file_size"
	else
		RED "Hubo un error en el proceso de compresión."
		echo "Últimas líneas del log [/var/log/tarbackup.log]:"
		tail -n 10 /var/log/tarbackup.log
		error
	fi
}

function main(){
	# Verificar si el script se está ejecutando como root
	check_root

	# Verificar si el comando tar está instalado
	check_tar_installed

	# Solicitar la ruta donde se guardará la copia de seguridad
	get_backup_path

	# Solicitar el directorio a respaldar
	get_backup_directory

	# Solicitar las rutas a excluir
	get_exclude_paths

	# Construir las opciones --exclude
	build_exclude_options

	# Crear el nombre del archivo de respaldo
	create_backup_name

	# Obtener el tamaño total del directorio
	get_backup_size

	# Iniciar la compresión del directorio
	start_compression

	# Monitorear el progreso de la compresión
	monitor_progress
}

main


