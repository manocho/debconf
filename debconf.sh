#!/bin/bash

# Verifica si el script se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ser ejecutado con privilegios de superusuario (root)."
  exit 1
fi
clear
debconf_dir="/etc/debconf"
debconf_file="state.inf"
nombreusuario=$(getent passwd 1000 | cut -d: -f1)
main_packages_file="main_packages.list"
docker_packages_file="docker_packages.list"

# Verificar si el directorio de estado debconf existe
if [ -d "$debconf_dir" ]; then
    debconf_status_line=$(grep "status: " "$debconf_dir/$debconf_file")
    debconf_status=$(echo "$debconf_status_line" | awk -F ": " '{print $2}')
    echo "debconf ya fué ejecutado en este sistema y se encuentra en estado $debconf_status"
    read -p "¿Ejecutar debconf de todas formas? [si/NO]: " debconf_run_answer
    debconf_run_answer=$(echo "$debconf_run_answer" | tr '[:upper:]' '[:lower:]')
    if [ "$debconf_run_answer" == "si" ]; then
        echo "Ejecutando debconf"
        # Agrega aquí el comando que deseas ejecutar
    else
        echo "Salgo"
        exit 1
    fi
else
    # Crear el directorio si no existe
    mkdir -p "$debconf_dir"
    echo "Directorio de configuración de debconf creado en $debconf_dir"
    echo "status: 0" > "$debconf_dir/$debconf_file"
fi

# Lee el hostname actual desde el archivo hosts
hostname_actual=$(cat /etc/hostname)
echo "El nombre de host actual es: $hostname_actual"

    read -p "¿Desea cambiarlo? [s/N]: " debconf_hostname_answer
    debconf_hostname_answer=$(echo "$debconf_hostname_answer" | tr '[:upper:]' '[:lower:]')
    if [ "$debconf_hostname_answer" == "s" ]; then
      # Función para verificar si un nombre de host es válido
      es_nombre_de_host_valido() {
        local nombre_de_host=$1
        # La expresión regular valida que el nombre de host consista en caracteres alfanuméricos y guiones (-)
        [[ "$nombre_de_host" =~ ^[a-zA-Z0-9-]+$ ]]
      }

      # Inicializa la variable del nuevo nombre de host
      nuevo_hostname=""

      # Continúa solicitando al usuario que ingrese el nuevo nombre de host hasta que se proporcione uno válido
      while true; do
        # Solicitar al usuario que ingrese el nuevo nombre de host
        echo "Ingresa el nuevo nombre de host (o presiona Enter para dejar el mismo):"
        read nuevo_hostname

        # Si no se proporciona un nuevo nombre, usa el actual
        if [ -z "$nuevo_hostname" ]; then
          nuevo_hostname=$hostname_actual
        fi

        # Verifica si el nombre de host es válido
        if ! es_nombre_de_host_valido "$nuevo_hostname"; then
          echo "El nombre de host contiene caracteres no válidos. Por favor, utiliza solo letras, números y guiones."
          continue
        fi

        break
      done

      # Realiza la sustitución en el archivo hosts
      sed -i "s/\b$hostname_actual\b/$nuevo_hostname/g" /etc/hosts
      sed -i "s/\b$hostname_actual\b/$nuevo_hostname/g" /etc/hostname

      # Verifica si la sustitución fue exitosa
      if [ $? -eq 0 ]; then
        echo "El nombre de host se ha cambiado a $nuevo_hostname."
      else
        echo "Error al cambiar el nombre de host."
      fi

        # Agrega aquí el comando que deseas ejecutar
    else
        echo "El hostname no se cambia"
    fi

## APTITUDE ##
echo "instalando paquetes base"
apt update
apt upgrade
main_packages=$(awk '{ printf "%s ", $1 }' "main_packages.list")
apt install -y " $main_packages"

# Desactivar IPv6 para avahi-daemon
sed -i "s/\buse-ipv6=yes\b/use-ipv6=no/g" /etc/avahi/avahi-daemon.conf
systemctl restart avahi-daemon.service

# Habilitar login root por SSH
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/login.conf

# Instalar Docker
read -p "¿Desea instalar DOCKER? [s/N]: " docker_install_answer
docker_install_answer=$(echo "$docker_install_answer" | tr '[:upper:]' '[:lower:]')
if [ "$docker_install_answer" == "s" ]; then
  echo "Instalando Docker"
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  docker_packages=$(awk '{ printf "%s ", $1 }' "docker_packages.list")
  apt install -y " $docker_packages"
  systemctl status docker -n 0
  systemctl enable docker
  usermod -aG sudo $nombreusuario
  usermod -aG docker $nombreusuario
else 
  echo "Docker no se instalará"
fi

# Instalar Shell-in-a-Box
read -p "¿Desea instalar SHELL-IN-A-BOX? [s/N]: " shellbox_install_answer
shellbox_install_answer=$(echo "$shellbox_install_answer" | tr '[:upper:]' '[:lower:]')
if [ "$shellbox_install_answer" == "s" ]; then
  echo "Instalando Shell-in-a-Box"
  apt install openssl shellinabox
  sed -i "s/\bSHELLINABOX_PORT=4200\b/SHELLINABOX_PORT=8022/g" /etc/default/shellinabox
  systemctl restart shellinabox
  systemctl enable shellinabox
else 
  echo "Shell-in-a-Box no se instalará"
fi

# Actualizo .bashsrc para root
echo "export LS_OPTIONS='--color=auto'" >> /root/.bashrc
echo "eval \"\$(dircolors)\"" >> /root/.bashrc
echo "alias ls='ls \$LS_OPTIONS'" >> /root/.bashrc
echo "alias ll='ls \$LS_OPTIONS -l'" >> /root/.bashrc
echo "alias l='ls \$LS_OPTIONS -lA'" >> /root/.bashrc
echo "alias rm='rm -i'" >> /root/.bashrc
echo "alias cp='cp -i'" >> /root/.bashrc
echo "alias mv='mv -i'" >> /root/.bashrc

# Pregunto si se debe reiniciar
echo "Finalizado"
read -p "¿Desea reiniciar? [s/N]: " reboot_answer
reboot_answer=$(echo "$reboot_answer" | tr '[:upper:]' '[:lower:]')
if [ "$reboot_answer" == "s" ]; then
  echo "Reiniciando..."
  reboot
else 
  echo "Fin del script."
fi