#!/bin/bash
#
# Licencia: MIT
# Este script es parte de sql2elk (https://github.com/argob/sql2elk)


### Definición de variables de ejecutables y argumentos
# Predefinidas
IS_DIGIT='^[0-9]+$'
CUT_CMD=/usr/bin/cut
CURL_CMD=/usr/bin/curl
LS_CMD=/usr/share/logstash/bin/logstash
COUNT_ARGS='--connect-timeout 10 -s'
CONNECT_ARGS='--connect-timeout 10 -s -o /dev/null'
STATUS_ARGS='--connect-timeout 10 -s -I -o /dev/null -w %{http_code}'

# Configurables via docker o .env
MODE=${MODE}
ES_PROTO=${ES_PROTO:?Setear protocolo (http o https)}
ES_HOST=${ES_HOST:?Setear variable ES_HOST=host de elasticsearch}
ES_PORT=${ES_PORT:?Setear variable ES_PORT=puerto http de elasticsearch}
INDEX=${INDEX:?Setear variable INDEX=indice de elasticsearch}
ES_URL=$ES_PROTO://$ES_HOST:$ES_PORT
DELAY=${DELAY:=2}
EXHAUSTED=${MAX_TRIES:=10}

# Logger para las funciones
function logger() {
    echo "`date +%H:%M:%S` : [$1] $2: \t"
}


# Entrypoint
function boot() {
    printf "$(logger INFO ${FUNCNAME[0]}) Arrancando Logstash "
    if [ $MODE == 'bulk' ] || [ $MODE == 'tracker' ]; then
        VALID_MODE=yes
        printf "en modo $MODE"
    fi
    printf "\nElasticsearch host: $ES_URL\n"
    connect
}

# Chequear la conexión con elasticsearch
function connect() {
    printf "$(logger INFO ${FUNCNAME[0]}) Esperando a elasticsearch, máximo de intentos: $MAX_TRIES, retardo: ${DELAY}s\n"
    local TRIES_COUNT=0
    while [ $TRIES_COUNT -lt $EXHAUSTED ]; do
        TRIES_COUNT=$[$TRIES_COUNT + 1]
        $CURL_CMD $CONNECT_ARGS $ES_URL
        if [ $? -ne 0 ]; then
            sleep $DELAY
            printf "$(logger WARN ${FUNCNAME[0]}) Intento $TRIES_COUNT - No se pudo conectar con elasticsearch en $ES_URL, esperando...\n"
        else
            printf "$(logger INFO ${FUNCNAME[0]}) Intento $TRIES_COUNT - Conectado a elasticsearch en $ES_URL\n"
            status
            break
        fi
        done
        printf "$(logger ERROR ${FUNCNAME[0]}) Fallo al cargar índice en elasticsearch @ $ES_URL.\n"
}

# Chequear el estado del índice
function status() {
    local HTTP_STATUS=`$CURL_CMD $STATUS_ARGS $ES_HOST:$ES_PORT/$INDEX`
    local CMD_STATUS=$?
    if [ $CMD_STATUS == 0 ]; then
        printf "$(logger INFO ${FUNCNAME[0]}) Obteniendo el índice $INDEX\n"
        case $HTTP_STATUS in
            200)
                local GRACEFUL_TRY=0
                while [ $GRACEFUL_TRY -lt $EXHAUSTED ]; do
                    GRACEFUL_TRY=$[$GRACEFUL_TRY + 1]
                    local DOC_COUNT=$(count)
                    if [[ $DOC_COUNT =~ $IS_DIGIT ]]; then             
                        mode $DOC_COUNT true
                        break
                    else
                        sleep 2
                    fi
                done
                printf "\n $(logger INFO ${FUNCNAME[0]}) No se pudo obtener el estado del índice\n"
                exit 1
                    ;;
            404)
                mode 0 false
                ;;
            *)
                printf "$(logger INFO ${FUNCNAME[0]}) Elasticsearch en $ES_HOST devolvió $HTTP_STATUS\n"
                exit 1
                ;;
        esac
    else
        printf "$(logger INFO ${FUNCNAME[0]}) No se pudo obtener el estado del índice\n"
        exit 1
    fi
}

# Obtener cantidad de documentos en indice
function count() {
    local DOCS=`$CURL_CMD $COUNT_ARGS $ES_URL/${INDEX}/_count 2>&1 /dev/null`
    local COUNT=$(echo $DOCS | cut -d ":" -f 2 | cut -d , -f 1)
    echo $COUNT
}
 
# Determinar modo de ejecución de logstash en base al estado del índice o variable y cargar plantilla
function mode() {
    $CURL_CMD -X PUT -s $ES_URL/_template/$INDEX -d @$LS_SETTINGS_DIR/conf.d/$INDEX.json
    if [ $VALID_MODE ]; then
        printf "$(logger INFO ${FUNCNAME[0]}) Ejecutando logstash en modo $MODE, definido por usuario\n"
        `$LS_CMD -f ${LS_SETTINGS_DIR}/conf.d/logstash-$MODE.conf`
        return 0
    fi
    if [ $2 ]; then
        if [ $1 -gt 0 ]; then
            printf "$(logger INFO ${FUNCNAME[0]}) El índice $INDEX existe con $1 documentos\n"
            loader tracker
        else
            printf "$(logger WARN ${FUNCNAME[0]}) El índice $INDEX existe pero sin documentos\n"
            loader bulk
        fi
    else
        printf "$(logger INFO ${FUNCNAME[0]}) El índice $INDEX no existe, ejecutando logstash en modo bulk\n"
        loader bulk
   fi 
}

# Ejecutar logstash en base el modo definido 
function loader () {
    printf "$(logger INFO ${FUNCNAME[0]}) Ejecutando logstash en modo $1\n"
    $LS_CMD -f ${LS_SETTINGS_DIR}/conf.d/logstash-$1.conf
}

boot