#!/bin/bash

# Nome do container Docker
CONTAINER_NAME="v7-culturaz-db-1"

# Dados de conexão
DB_NAME="mapas"
DB_USER="mapas"

echo "===> Iniciando alteração de colunas da tabela 'pcache' para BIGINT..."
START_TIME=$(date +%s)

# Executa os comandos SQL dentro do container
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<'EOF'
BEGIN;
    ALTER TABLE public.pcache
        ALTER COLUMN id TYPE BIGINT,
        ALTER COLUMN user_id TYPE BIGINT,
        ALTER COLUMN object_id TYPE BIGINT;
COMMIT;
EOF

# Verifica se houve erro
EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Alteração concluída com sucesso em $DURATION segundos."
else
    echo "❌ Ocorreu um erro durante a alteração. Código de saída: $EXIT_CODE"
fi
