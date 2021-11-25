FROM ubuntu:20.04

LABEL authors="Rafael Sene - rpsene@br.ibm.com"

WORKDIR /output

ENV API_KEY=""
ENV IBMCLOUD_ID=""
ENV IBMCLOUD_NAME=""

RUN apt-get update; apt-get -y install jq curl wget python3 python3-pip libpq-dev python-dev build-essential

RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | sh; ibmcloud plugin install power-iaas

COPY collect.sh /collect.sh
COPY json_reader.py /json_reader.py

ENTRYPOINT ["/usr/bin/bash", "/collect.sh"]