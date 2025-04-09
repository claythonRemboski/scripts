#!/bin/bash

set -e

# VARIÁVEIS:
DB_USER="clinicanasnuvens"
DB_PASS="mandeum"
DB_NAME="clinicanasnuvens"
DB_HOST="db-clinicanasnuvens"
NETWORK_NAME="php-clinicanasnuvens-networks"
PORT="914"
URLTMOLE=""
DOWNLOAD_DIR="$HOME/Downloads"

# ------------------ETAPA 2 AMBIENTE------------------------------

#1 Copia .env.example se existir:
if [ -f .env.example ]; then
    cp .env.example .env
    echo ".env criado à partir de .env.example."

    # 2: Atualiza as variáveis de ambiente usando as variáveis do script:
    sed -i "s/^APP_DEBUG=.*/APP_DEBUG=false/" .env

    sed -i "s/^APP_ENV=.*/APP_ENV=local/" .env
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env
    sed -i "s/^DB_HOST=.*/DB_HOST=$DB_HOST/" .env

    echo "Dados atualizados: APP_ENV, DB_DATABASE, DB_USERNAME, DB_PASSWORD e DB_HOST no arquivo .env."
else
    echo ".env.example não encontrado, verifique se realmente existe na pasta"
    exit 1
fi

# 3: sobe os containeres Docker

# Verifica se a rede já existe
if docker network ls --filter name=^${NETWORK_NAME}$ --format "{{.Name}}" | grep -q "^${NETWORK_NAME}$"; then
    echo "A rede Docker '$NETWORK_NAME' já existe, pulando criação."
else
    echo "Criando a rede Docker '$NETWORK_NAME'..."
    docker network create $NETWORK_NAME
fi

echo "Subindo containeres Docker..."
if ! sudo docker compose up -d --build; then
    echo "Erro ao subir os containers Docker. Verifique os logs e tente novamente."
    exit 1
fi

echo "Aguardando database estar disponível"

until sudo docker exec -i db-clinicanasnuvens mysql -u$DB_USER -p$DB_PASS -e "SELECT 1" &>/dev/null; do
    echo "MySQL ainda indisponível. Aguarde..."
    sleep 3
done

echo "Conteineres em funcionamento"

# Criando diretorios e atribuindo permissoes iniciais:
mkdir -p vendor
mkdir -p bootstrap/cache
sudo chown -R 1001:1001 .
sudo chmod -R 775 storage bootstrap/cache

# 4: Função para aguardar comandos de criação de dependências:
aguardar_execucao() {
    local mensagem="$1"
    local comando="$2"

    echo "$mensagem"
    until eval "$comando"; do
        echo "Aguarde..."
        sleep 2
    done
}

# Executando comandos
aguardar_execucao "Atualizando dependências com Composer..." "sudo docker compose exec php-clinicanasnuvens composer update"
aguardar_execucao "Gerando chave de aplicação..." "sudo docker compose exec php-clinicanasnuvens php artisan key:generate"
aguardar_execucao "Rodando migrações do banco de dados..." "sudo docker compose exec php-clinicanasnuvens php artisan migrate"
aguardar_execucao "Definindo permissões no diretório de storage..." "sudo docker compose exec php-clinicanasnuvens chmod -R 777 ./storage/"

# Verificar se o servidor foi iniciado
sleep 3
if sudo lsof -i:$PORT &>/dev/null; then
    echo "Aplicação Laravel servida com sucesso em http://localhost:$PORT."
else
    echo "Erro: Não foi possível iniciar o servidor Laravel. Verifique os logs."
    exit 1
fi

# 5 - tunelmole

# Verificar se o Tunnelmole está instalado
if ! command tmole -V &> /dev/null
then
    echo "Tunnelmole não está instalado. Instalando..."

    # Baixar o instalador do Tunnelmole para a pasta Downloads
    curl -o "$DOWNLOAD_DIR/install" https://install.tunnelmole.com/n3d5g/install

    # Dar permissão de execução ao arquivo baixado e executar a instalação
    chmod +x "$DOWNLOAD_DIR/install"
    cd $DOWNLOAD_DIR
    sudo bash "$DOWNLOAD_DIR/install"
else
    echo "Tunnelmole já está instalado, pulando instalação."
fi

TMOLE_PID=$(ps aux | grep '[t]mole' | awk '{print $2}')

if [ -n "$TMOLE_PID" ]; then
    echo "Matando o processo tmole com PID $TMOLE_PID..."
    kill -9 $TMOLE_PID
    echo "Processo tmole encerrado."
fi
# Executar o tmole e capturar a saída diretamente na variável
nohup tmole $PORT > $DOWNLOAD_DIR/tmole_output.log 2>&1 &

sleep 2

# Capturar a primeira URL HTTP gerada pelo tmole na variável
URLTMOLE=$(grep -oP 'https://[^\s]+' $DOWNLOAD_DIR/tmole_output.log | head -n 1)

# Verificar se a URL foi capturada corretamente
if [ -z "$URLTMOLE" ]; then
    echo "Erro: Não foi possível capturar a URL do Tunnelmole."
else
    # Exibir a URL capturada
    echo "Projeto rodando e disponível no link $URLTMOLE"
    echo "Link Webhook: $URLTMOLE/api/v1/webhook/digisac/bot-command"
fi
rm -f $DOWNLOAD_DIR/tmole_output.log