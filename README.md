# TarBackup

TarBackup es un script en Bash diseñado para realizar copias de seguridad de directorios en sistemas Linux utilizando el comando `tar`. Este script es ideal para administradores de sistemas y usuarios que buscan una solución sencilla y eficiente para respaldar sus datos.

## Características

- Verificación de rutas absolutas y existencia de directorios.
- Comprobación de permisos de root para ejecutar el script.
- Verificación de la instalación del comando `tar`.
- Solicitud interactiva de la ruta de destino para la copia de seguridad.
- Solicitud interactiva del directorio a respaldar.
- Exclusión de rutas específicas del respaldo.
- Monitoreo del progreso de la compresión.
- Registro de la actividad en un archivo de log.

## Requisitos

- Sistema operativo Linux.
- Bash shell.
- Comando `tar` instalado.

## Instalación

1. Clona este repositorio en tu máquina local:
    ```sh
    git clone https://github.com/tu-usuario/tarbackup.git
    ```
2. Navega al directorio del script:
    ```sh
    cd tarbackup
    ```
3. Asegúrate de que el script tenga permisos de ejecución:
    ```sh
    chmod +x tarbackup.sh
    ```

## Uso

1. Ejecuta el script con permisos de root:
    ```sh
    sudo ./tarbackup.sh
    ```
2. Sigue las instrucciones interactivas para configurar la copia de seguridad:
    - Selecciona la ruta donde se guardará la copia.
    - Selecciona el directorio que deseas respaldar.
    - Indica las rutas que deseas excluir del respaldo.

## Ejemplo de Ejecución

```sh
$ sudo tarbackup.sh
Seleccione la ruta absoluta donde se guardará la copia [default: /root/backups]: /home/user/backups
Seleccione el directorio que desea respaldar [default: /]: /home/user/documents
Indique las rutas que desea excluir separadas por comas [example: /home/tarbackup,/var]: /home/user/documents/temp
Calculando el tamaño total del directorio...
Tamaño total del directorio: 500 M
Compresión en progreso: [##############################] 500/500 MB (100%)
Archivo creado: /home/user/backups/documents-hostname-20230101123000.tar.gz
El tamaño total del archivo comprimido es: 100M