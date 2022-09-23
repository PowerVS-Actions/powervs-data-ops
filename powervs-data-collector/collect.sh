#!/bin/bash

: '
    Copyright (C) 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "Bye!"
    exit 0
}

function check_dependencies() {
    echo "* checking dependencies..."
    DEPENDENCIES=(ibmcloud curl sh wget jq python3)
    check_connectivity
    for i in "${DEPENDENCIES[@]}"
    do
        if ! command -v "$i" &> /dev/null; then
            echo "$i could not be found, exiting!"
            exit 1
        fi
    done
}

function check_connectivity() {
    echo "* checking internet connectivity..."
    if ! curl --output /dev/null --silent --head --fail http://cloud.ibm.com; then
        echo "ERROR: please, check your internet connection."
        exit 1
    fi
}

function authenticate() {
    echo "* authenticating..."
    local APY_KEY="$1"

    if [ -z "$APY_KEY" ]; then
        echo "API KEY was not set."
        exit
    fi
    ibmcloud update -f > /dev/null 2>&1
    ibmcloud plugin update --all > /dev/null 2>&1
    ibmcloud login --no-region --apikey "$APY_KEY" > /dev/null 2>&1
}

function set_powervs() {
    echo "* setting powervs instance as active..."
    local CRN="$1"

    if [ -z "$CRN" ]; then
        echo "CRN was not set."
        exit 1
    fi
    ibmcloud pi st "$CRN" > /dev/null 2>&1
}

function get_instances_data(){
    echo "  - getting data from VMs..."
    local TODAY
    TODAY=$(date '+%Y%m%d')
    local PVS_NAME=$1
    local IBMCLOUD_ID=$2
    local IBMCLOUD_NAME=$3
    local PVS_ZONE=$4
    local INSTANCES=($(ibmcloud pi ins --json | jq -r '.pvmInstances[] | "\(.pvmInstanceID)"'))

    for in in "${INSTANCES[@]}"; do
        ibmcloud pi in "$in" --json >> "$(pwd)/$IBMCLOUD_ID/$in.json"
        python3 /json_reader.py "$IBMCLOUD_ID/$in.json" "$PVS_NAME" "$IBMCLOUD_ID" "$IBMCLOUD_NAME" "$PVS_ZONE"
    done
}

function get_vms_per_crn(){

    echo "* getting all CRNs..."
    local TODAY
    TODAY=$(date '+%Y%m%d')
    local IBMCLOUD_ID="$1"

	rm -f "$(pwd)/$IBMCLOUD_ID/crns-$TODAY-$IBMCLOUD_ID"
	ibmcloud pi service-list --json | jq -r '.[] | "\(.CRN),\(.Name)"' >> "$(pwd)/$IBMCLOUD_ID/crns-$TODAY-$IBMCLOUD_ID"

    echo "* getting all VMs in a powervs service..."
	while read -r line; do
        local CRN
        CRN=$(echo "$line" | awk -F ',' '{print $1}')
        local NAME
        NAME=$(echo "$line" | awk -F ',' '{print $2}')
        local POWERVS_ZONE
        POWERVS_ZONE=$(echo "$line" | awk -F ':' '{print $6}')
        local IBMCLOUD_ID="$1"
		set_powervs "$CRN"
        echo "  - collecting data from $NAME..."
        get_instances_data "$NAME" "$IBMCLOUD_ID" "$2" "$POWERVS_ZONE"
	done < "$(pwd)/$IBMCLOUD_ID/crns-$TODAY-$IBMCLOUD_ID"
}

function run (){

    if [ -z "$IBMCLOUD_ID" ]; then
        echo "ERROR: please, set your IBM Cloud ID."
        exit 1
    fi

    if [ -z "$IBMCLOUD_NAME" ]; then
        echo "ERROR: please, set your IBM Cloud name."
        exit 1
    fi

    if [ -z "$API_KEY" ]; then
        echo
        echo "ERROR: please, set your IBM Cloud API Key."
        echo "		 e.g ./vms-age.sh API_KEY"
        echo
        exit 1
    else
        check_dependencies
        check_connectivity
        authenticate "$API_KEY"

        if [ -d "$IBMCLOUD_ID" ]; then
            rm -rf "${IBMCLOUD_ID:?}"
            mkdir -p "$IBMCLOUD_ID"
        else
            mkdir -p "$IBMCLOUD_ID"
        fi
        get_vms_per_crn "$IBMCLOUD_ID" "$IBMCLOUD_NAME"
    fi
}

run "$@"
