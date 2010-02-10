#!/bin/bash

function od_message_out
{
    SCRIPT_NAME=$(basename $0)
    now=$(date +%H:%M:%S)
    echo "[$SCRIPT_NAME ($now)] $@"
}

function od_message_err
{
    SCRIPT_NAME=$(basename $0)
    now=$(date +%H:%M:%S)
    echo "[$SCRIPT_NAME ($now)] $@" >&2
}

function od_message_exit
{
    od_message_err "$@"
    exit 1;
}

REQUIRED_USER="wikid"

if [ "x$USER" == "x$REQUIRED_USER" ]; then
    od_message_out "Starting script..."

    cd $HOME

    umask 077
    mkdir .ssh

    umask 022
    touch .ssh/authorized_keys
    
    echo command="run_wikid_rpc.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA+MyAjQHRsQMlJnXvLE50PmvFBh7uHS6BcSmigF9/KtY6WP5yry4fVa/TSwaJwT2jadyHnzFrUh4wMmfTkL1J0l6iQLLhyM5aF9OgDR0rbMFYiSIfTA8liiHDZ0bqOn7cbv93uESRd6HkefMhXRoGGWGhvx8kfVecDqk/893gNkpwfReyA/QW+5QMZF4uSLnVlhXlnDZ4TxuLQqj1ScE98k99SdlE//aAyDhr5FHZXUrhTJcMJ8LZwLsADcGwq55WXB0i8nJmBp2SZJ/cop+qRN0h+k/zcu5c3heY6Q6xplLgjf9bdlpoH3HyhmJ1mU7ccRYJUH1ZMNqO/C76llcqFw== wikid@SillyCatFace >> .ssh/authorized_keys

else
    od_message_err "Only $REQUIRED_USER can run this script."
fi
