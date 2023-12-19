#!/bin/bash

# Verifica si el script se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ser ejecutado con privilegios de superusuario (root)."
  exit 1
fi

# Lee el hostname actual desde el archivo hosts
hostname_actual=$(cat /etc/hostname)

echo "El nombre de host actual es: $hostname_actual"

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

## APTITUDE ##
echo "instalando paquetes base"
apt update
apt install htop curl wget avahi-daemon software-properties-common apt-transport-https ca-certificates curl gnupg lsb-release mc


## DOCKER ##
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose
systemctl status docker
systemctl enable docker

nombreusuario=$(getent passwd 1000 | cut -d: -f1)
usermod -aG sudo $nombreusuario
usermod -aG docker $nombreusuario
