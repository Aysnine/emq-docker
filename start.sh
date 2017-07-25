#!/bin/sh
## EMQ docker image start script
# Huang Rui <vowstar@gmail.com>

## Shell setting
if [[ ! -z "$DEBUG" ]]; then
    set -ex
fi

## Local IP address setting

#LOCAL_IP=$(hostname -i |grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])'|head -n 1)
LOCAL_IP=$(ifconfig eth0 | grep "inet addr" | awk '{ print $2}' | awk -F: '{print $2}')
EMQ_NAME=emq
## EMQ Base settings and plugins setting
# Base settings in /opt/emqttd/etc/emq.conf
# Plugin settings in /opt/emqttd/etc/plugins

_EMQ_HOME="/opt/emqtt"

if [[ -z "$PLATFORM_ETC_DIR" ]]; then
    export PLATFORM_ETC_DIR="$_EMQ_HOME/etc"
fi

if [[ -z "$PLATFORM_LOG_DIR" ]]; then
    export PLATFORM_LOG_DIR="$_EMQ_HOME/log"
fi

if [[ -z "$EMQ_NAME" ]]; then
    export EMQ_NAME="$(hostname)"
fi

if [[ -z "$EMQ_HOST" ]]; then
    export EMQ_HOST="$LOCAL_IP"
fi

if [[ -z "$EMQ_NODE__NAME" ]]; then
    export EMQ_NODE__NAME="$EMQ_NAME@$EMQ_HOST"
fi

# Set hosts to prevent cluster mode failed

if [[ ! -z "$LOCAL_IP" && ! -z "$EMQ_HOST" ]]; then
    echo "$LOCAL_IP        $EMQ_HOST" >> /etc/hosts
fi

# unset EMQ_NAME
# unset EMQ_HOST

if [[ -z "$EMQ_NODE__PROCESS_LIMIT" ]]; then
    export EMQ_NODE__PROCESS_LIMIT=2097152
fi

if [[ -z "$EMQ_NODE__MAX_PORTS" ]]; then
    export EMQ_NODE__MAX_PORTS=1048576
fi

if [[ -z "$EMQ_NODE__MAX_ETS_TABLES" ]]; then
    export EMQ_NODE__MAX_ETS_TABLES=2097152
fi

if [[ -z "$EMQ_LOG__CONSOLE" ]]; then
    export EMQ_LOG__CONSOLE="console"
fi

if [[ -z "$EMQ_LISTENER__TCP__EXTERNAL__ACCEPTORS" ]]; then
    export EMQ_LISTENER__TCP__EXTERNAL__ACCEPTORS=64
fi

if [[ -z "$EMQ_LISTENER__TCP__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQ_LISTENER__TCP__EXTERNAL__MAX_CLIENTS=1000000
fi

if [[ -z "$EMQ_LISTENER__SSL__EXTERNAL__ACCEPTORS" ]]; then
    export EMQ_LISTENER__SSL__EXTERNAL__ACCEPTORS=32
fi

if [[ -z "$EMQ_LISTENER__SSL__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQ_LISTENER__SSL__EXTERNAL__MAX_CLIENTS=500000
fi

if [[ -z "$EMQ_LISTENER__WS__EXTERNAL__ACCEPTORS" ]]; then
    export EMQ_LISTENER__WS__EXTERNAL__ACCEPTORS=16
fi

if [[ -z "$EMQ_LISTENER__WS__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQ_LISTENER__WS__EXTERNAL__MAX_CLIENTS=250000
fi

# Catch all EMQ_ prefix environment variable and match it in configure file
CONFIG=/opt/emqttd/etc/emq.conf
CONFIG_PLUGINS=/opt/emqttd/etc/plugins
for VAR in $(env)
do
    # Config normal keys such like node.name = emqttd@127.0.0.1
    if [[ ! -z "$(echo $VAR | grep -E '^EMQ_')" ]]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s/EMQ_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | sed -r "s/__/\./g")
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g")
        # Config in emq.conf
        if [[ ! -z "$(cat $CONFIG |grep -E "^(^|^#*|^#*\s*)$VAR_NAME")" ]]; then
            echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s/(^#*\s*)($VAR_NAME)\s*=\s*(.*)/\2 = $(eval echo \$$VAR_FULL_NAME)/g" $CONFIG
        fi
        # Config in plugins/*
        if [[ ! -z "$(cat $CONFIG_PLUGINS/* |grep -E "^(^|^#*|^#*\s*)$VAR_NAME")" ]]; then
            echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s/(^#*\s*)($VAR_NAME)\s*=\s*(.*)/\2 = $(eval echo \$$VAR_FULL_NAME)/g" $(ls $CONFIG_PLUGINS/*)
        fi        
    fi
    # Config template such like {{ platform_etc_dir }}
    if [[ ! -z "$(echo $VAR | grep -E '^PLATFORM_')" ]]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g"| tr '[:upper:]' '[:lower:]')
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g")
        sed -r -i "s@\{\{\s*$VAR_NAME\s*\}\}@$(eval echo \$$VAR_FULL_NAME)@g" $CONFIG
    fi
done

## EMQ Plugin load settings
# Plugins loaded by default

if [[ ! -z "$EMQ_LOADED_PLUGINS" ]]; then
    echo "EMQ_LOADED_PLUGINS=$EMQ_LOADED_PLUGINS"
    # First, remove special char at header
    # Next, replace special char to ".\n" to fit emq loaded_plugins format
    echo $(echo "$EMQ_LOADED_PLUGINS."|sed -e "s/^[^A-Za-z0-9_]\{1,\}//g"|sed -e "s/[^A-Za-z0-9_]\{1,\}/\. /g")|tr ' ' '\n' > /opt/emqttd/data/loaded_plugins
fi

## EMQ Main script

# Start and run emqttd

/opt/emqttd/bin/emqttd start

