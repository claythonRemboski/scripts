#!/bin/bash

# Obtém o caminho do diretório atual
current_directory=$(pwd)

# Verifica se o parâmetro 'docker' está presente
if [[ "$1" == "-docker" ]]; then
    # Executa o comando docker compose up -d no diretório atual
    (cd "$current_directory" && docker-compose up -d)
fi

# Abre o VSCode no diretório atual
code .
