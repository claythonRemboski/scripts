#!/bin/bash

# Função para checar se um programa está instalado
is_installed() {
  command -v $1 > /dev/null 2>&1
}

# Função para instalar um programa usando apt
install_package() {
  if ! is_installed $1; then
    sudo apt install -y $1
  else
    echo "$1 já está instalado. Pulando a instalação."
  fi
}

# Função para baixar e instalar programas a partir de URLs
install_from_url() {
  program=$1
  url=$2
  install_path=$3

  if ! is_installed $program; then
    echo "Baixando e instalando $program..."
    wget -O /tmp/$program $url
    sudo dpkg -i /tmp/$program
    rm /tmp/$program
  else
    echo "$program já está instalado. Pulando a instalação."
  fi
}

# Atualizar o sistema
echo "Atualizando o sistema..."
sudo apt update
sudo apt upgrade -y

# Instalar programas disponíveis no repositório do Pop_OS!
install_package postman