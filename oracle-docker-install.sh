#!/usr/bin/env bash
#
#-------------------------------------------------------
#
# autor: Luciano Brito
# author: Luciano Brito
#
#-------------------------------------------------------
#
# Creation
#
# Data: 25/10/2022 as 22:00
# Date: 25/10/2022 at 10:00 pm
#
#-------------------------------------------------------
#
# Contacts
#
# e-mail: lucianobrito.dev@gmail.com
# github: github.com/lucianobritodev
#
#-------------------------------------------------------
#
# Versions
#
# v1.0.0 - Project created
# 
#
#-------------------------------------------------------
#
# Para executar o script execute os seguintes comandos:
# To run the script run one of the following commands:
#
# ./oracle-docker-install.sh
#
# or
#
# bash oracle-docker-install.sh
#-------------------------------------------------------
#
#
####################### VARABLES #######################


DOCKER_IS_INSTALLED=$(which docker)
SUDO_PASSWORD=$(zenity --password)

ORACLE_IMAGE="gvenzl/oracle-xe"
ORACLE_PASSWORD="sysdba"

CONTAINER_SCRIPTS_PATH=/opt/oracle/scripts
CONTAINER_VOLUME=/opt/oracle/oradata
CONTAINER_NAME="oracle-21c-dev"
CONTAINER_ID=
CONTAINER_PORT=1521

HOST_VOLUME=/opt/docker-volumes/oracle/oradata
HOST_PORT=1521


####################### FUNCTIONS ######################

function dockerInstall() {

    echo ${SUDO_PASSWORD} | sudo -S apt update
    echo ${SUDO_PASSWORD} | sudo -S apt upgrade
    echo ${SUDO_PASSWORD} | sudo -S apt install docker docker-compose -y
    echo ${SUDO_PASSWORD} | sudo -S groupadd docker
    echo ${SUDO_PASSWORD} | sudo -S usermod -aG docker $USER
    newgrp docker
    echo ${SUDO_PASSWORD} | sudo -S systemctl restart docker
    sleep 3
}


function dockerConfig() {

    createVolume

    docker run -d --name ${CONTAINER_NAME} -p ${HOST_PORT}:${CONTAINER_PORT} -e ORACLE_PASSWORD=${ORACLE_PASSWORD} -e BASE_USER=$USER -e CONTAINER_SCRIPTS_PATH=${CONTAINER_SCRIPTS_PATH} ${ORACLE_IMAGE}
    CONTAINER_ID=$(docker ps -a | grep ${CONTAINER_NAME} | awk {'print $1'})
    
    echo -e "\n\e[1;30m...Oracle Databases está sendo inicializado!\e[0m\n"

    ID_FULL=$(docker inspect ${CONTAINER_ID} | grep "\"Id\":" | sed 's/\"Id\": \"//;s/\",$//' | xargs)

    while true; do
        count=$(echo ${SUDO_PASSWORD} | sudo -S wc -l /var/lib/docker/containers/${ID_FULL}/${ID_FULL}-json.log | awk '{print $1}' | xargs)
        if [[ ${count} -ge 74 ]]; then
            docker exec -it ${CONTAINER_ID} bash -c 'mkdir -p ${CONTAINER_SCRIPTS_PATH}'
            docker exec -it ${CONTAINER_ID} bash -c 'echo -e "alter session set \"_oracle_script\"=true;\ncreate user $BASE_USER identified by sysdba;\ngrant all privileges to $BASE_USER;\nquit;" > ${CONTAINER_SCRIPTS_PATH}/script.sql'
            docker exec -it ${CONTAINER_ID} bash -c 'echo -e "#!/bin/bash\nsqlplus -s sys/${ORACLE_PASSWORD}@${ORACLE_SID} as sysdba <<< @${CONTAINER_SCRIPTS_PATH}/script.sql;\nexit 0;" > ${CONTAINER_SCRIPTS_PATH}/create-user-basic.sh'
            docker exec -it ${CONTAINER_ID} bash -c 'chmod +x ${CONTAINER_SCRIPTS_PATH}/create-user-basic.sh'
            docker exec -d ${CONTAINER_ID} bash -c 'sh ${CONTAINER_SCRIPTS_PATH}/create-user-basic.sh'
            break;
        else
            sleep 3
            continue;
        fi
    done


    RUNNING="$(docker ps -a | grep "${CONTAINER_ID}" | awk '{print $7}' | tr [A-Z] [a-z] | xargs)"
    [[ ${RUNNING} == 'up' ]] && messageSuccess || messageError
 
}


function createVolume() {

    if [[ -d ${HOST_VOLUME} ]]; then
        echo ${SUDO_PASSWORD} | sudo -S rm -Rf ${HOST_VOLUME}
        echo -e "\e[1;30m...Volume anterior removido!\e[0m\n"
    fi

    echo ${SUDO_PASSWORD} | sudo -S mkdir -p ${HOST_VOLUME}
    echo -e "\e[1;30m...Criando unidade de volume para o Oracle Databases em: ${HOST_VOLUME}\e[0m\n"

}


function messageSuccess() {

    zenity --notification --text="Container Oracle instalado com sucesso\!\n \
    DADOS DE CONEXÃO:\n \
    user: $USER\n \
    password: $ORACLE_PASSWORD\n \
    type: Basic\n \
    host: localhost\n \
    port: $PORT\n \
    SID: XE\n\n \
    CONTAINER_ID: $CONTAINER_ID\n \
    CONTAINER_NAME: $CONTAINER_NAME"

    echo -e "\n\e[1;32mContainer Oracle instalado com sucesso!\e[0m\n"
    echo -e "\e[1;30mDados de conexão:\e[0m\n"
    echo "user: $USER"
    echo "password: $ORACLE_PASSWORD"
    echo "type: Basic"
    echo "host: localhost"
    echo "port: $PORT"
    echo "SID: XE"
    echo ""
    echo "CONTAINER_ID: $CONTAINER_ID"
    echo "CONTAINER_NAME: $CONTAINER_NAME"

}


function messageError() {

    zenity --notification --text="Algo deu errado\!\n \
    Container Oracle não foi instalado corretamente\! \
    Considere refazer a instalação."

    echo -e "\n\e[1;31mContainer Oracle não foi instalado corretamente! Considere refazer a instalação.\e[0m\n"

}


######################## EXECUTION #####################


if ! [[ -x ${DOCKER_IS_INSTALLED} ]]; then
    dockerInstall ;
fi

dockerConfig


########################## END ########################
