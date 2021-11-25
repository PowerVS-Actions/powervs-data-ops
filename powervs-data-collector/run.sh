#!/bin/bash

: '
    Copyright (C) 2021 IBM Corporation
    Rafael Sene <rpsene@br.ibm.com> - Initial implementation.
'

WORKSPACE="all-vms"

function check_dependencies() {

	if command -v "podman" &> /dev/null; then
	   echo "Setting podman as container runtime..."
	   export CONTAINER_RUNTIME="podman"
	elif command -v "docker" &> /dev/null; then
	   echo "Setting docker as container runtime..."
	   export CONTAINER_RUNTIME="docker"
	else
	   echo "ERROR: please, install either podman or docker!"
	   exit 1
	fi
}

function run (){

    check_dependencies
	ACCOUNTS=()
	CONTAINER_IDS=()

	while IFS= read -r line; do
		clean_line=$(echo "$line" | tr -d '\r')
		ACCOUNTS+=("$clean_line")
	done < ./cloud_accounts

    # Ensure we start a fresh data processing
    if [ -d "$WORKSPACE" ]; then
        rm -rf "${WORKSPACE:?}"
        mkdir -p "$WORKSPACE"
    else
        mkdir -p "$WORKSPACE"
    fi

	rm -f ./.containers_id*
	rm -f ./all_vms.csv
	rm -rf ./all-vms

	for i in "${ACCOUNTS[@]}"; do
        IBMCLOUD=$(echo "$i" | awk -F "," '{print $1}')
		IBMCLOUD_ID=$(echo "$IBMCLOUD" | awk -F ":" '{print $1}')
		IBMCLOUD_NAME=$(echo "$IBMCLOUD" | awk -F ":" '{print $2}')
		API_KEY=$(echo "$i" | awk -F "," '{print $2}')
		echo "Collecting data from $IBMCLOUD_ID ($IBMCLOUD_NAME)"
        # starts the base container with the basic set of env vars
        container_id=$("$CONTAINER_RUNTIME" run -d -t --rm --name "vm-collector-$IBMCLOUD_ID" \
        -v "$(pwd)"/"$WORKSPACE":/output \
        -e API_KEY="$API_KEY" \
        -e IBMCLOUD_ID="$IBMCLOUD_ID" \
        -e IBMCLOUD_NAME="$IBMCLOUD_NAME" \
        powervs-data-collect:latest)
		CONTAINER_IDS+=("$container_id")
	done

	for cid in "${CONTAINER_IDS[@]}"; do
		echo "$cid" >> ./.containers_id
	done

	while [ ${#CONTAINER_IDS[@]} != 0 ]; do
		IFS=$'\n' read -d '' -r -a CONTAINER_IDS < ./.containers_id
		echo -ne "(Running ${#CONTAINER_IDS[@]} containers...) \033[0K\r"
		for cid in "${CONTAINER_IDS[@]}"; do
			if [ ! "$($CONTAINER_RUNTIME ps -q -f id="$cid")" ]; then
				sed -i -e "/$cid/d" ./.containers_id
			fi
		done
	done

	for i in "${ACCOUNTS[@]}"; do
			IBMCLOUD=$(echo "$i" | awk -F "," '{print $1}')
			IBMCLOUD_ID=$(echo "$IBMCLOUD" | awk -F ":" '{print $1}')
			IBMCLOUD_NAME=$(echo "$IBMCLOUD" | awk -F ":" '{print $2}')
			cat "$(pwd)/all-vms/$IBMCLOUD_ID/${IBMCLOUD_ID}_vms.csv" >> "$(pwd)/all-vms/all_vms.csv"
	done

	echo "Pushing data (all_vms.csv) to the database at IBM Cloud..."
	if [ -s "$(pwd)/all-vms/all_vms.csv" ]; then
		container_id=$("$CONTAINER_RUNTIME" run -d -t --rm --name "powervs-data-insert" -v "$(pwd)"/all-vms/all_vms.csv:/input/all_vms.csv powervs-data-insert:latest /input/all_vms.csv)

		data_added=0
		while [ $data_added != 1 ]; do
			if [ ! "$($CONTAINER_RUNTIME ps -q -f id="$container_id")" ]; then
				data_added=1
			fi
		done
		if [ $data_added != 1 ]; then
			echo "Data was successfully added!"
		fi
	else
		echo "ERROR: all_vms.csv either does not exists or is empty."
		exit 1
	fi
}

run "$@"
