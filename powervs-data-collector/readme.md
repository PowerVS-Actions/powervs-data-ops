# How to run

* 1 - Build both container images

    cd ./databse-ops
    docker build -t powervs-data-insert:latest -f Dockerfile.python

    Note: ensure you have set the data in the postgres.ini and the ssl.crt.

    cd ./powervs-data-collector
    docker build -t powervs-data-collect:latest -f Dockerfile.bash

* 2 - Add the information about the cloud accounts you want to collect data from in the file cloud_accounts using the following format (one cloud account per line):

    IBM Cloud Account ID:IBM Cloud Account Name,API_KEY
    2023450:my-cloud-account,acbdefghijklmnopqrstuvxz1234567890

* 3 - Run:

    ./run.sh
