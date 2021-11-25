"""
Copyright (C) 2021 IBM Corporation

Licensed under the Apache License, Version 2.0 (the “License”);
you may not use this file except in compliance with the License.

You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an “AS IS” BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

    Contributors:
        * Rafael Sene <rpsene@br.ibm.com>
"""

import subprocess
import sys
import json
from datetime import date


def execute(command):
    ''' Execute a command with its parameters and return the exit code '''
    try:
        process = subprocess.Popen([command],shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        return stdout
    except subprocess.CalledProcessError as excp:
        return excp.returncode


def cmdexists(command):
    '''Check if a command exists'''
    subp = subprocess.call("type " + command, shell=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return subp == 0


def index(data_list, target):
    '''Returns the index of an entry in a given array'''
    for item, possible_target in enumerate(data_list):
        if target in possible_target:
            return item
    return -1


def save_data(vm_data,ibmcloud_id):
    try:
        file_object = open("./" + ibmcloud_id + "/" + ibmcloud_id + "_vms.csv", "a")
        file_object.write(vm_data + "\n")
        file_object.close()
    except IOError as error:
        print (error)


def process_data(vm,pvs_name,ibmcloud_id,ibm_cloud_name,pvs_zone):
    '''Process the data collected from a given VM'''

    total_storage=0
    total_tier1=0
    total_tier3=0

    # reads the json with the information about the vm
    try:
        data=json.load(open(vm,))
    except ValueError as e:
        print('invalid json: %s' % e)

    if data:
        # get the number of days since the VM was created
        full_date=str(data["creationDate"]).split("T")[0]
        year=int(full_date.split("-")[0])
        month=int(full_date.split("-")[1])
        day=int(full_date.split("-")[2])

        raw_days_since_creation=(date.today() - date(year,month,day))
        days_since_creation=str(raw_days_since_creation).split(",")[0].split(" ")[0]
        if days_since_creation == "0:00:00":
            days_since_creation = 0

        number_volumes_attached=len(data["volumeIDs"])

        for volume in data["volumeIDs"]:
            raw_data=execute("ibmcloud pi volume --json " + volume)
            # this if statement ensures we do not handle the return value from the bash command excution
            size=0
            if not isinstance(raw_data, int):
                array_data=str(raw_data).strip().split(",")
                if array_data:
                    if index(array_data,"size") != -1:
                        raw_size=array_data[index(array_data,"size")]
                        size=(raw_size.split(":")[1].strip())
                    if index(array_data,"tier") != -1:
                        raw_tier=array_data[index(array_data,"tier")]
                        tier=(raw_tier.split(":")[1].strip().replace("\"",""))
                if size:
                    total_storage+=(int(size))
                    if "tier1" in tier:
                        total_tier1+=(int(size))
                    if "tier3" in tier:
                        total_tier3+=(int(size))

        pub_ip_index = index(data["networks"],"externalIP") if index(data["networks"],"externalIP") != -1 else index(data["addresses"],"externalIP")

        if pub_ip_index != -1:
            pub_ip = data["networks"][int(pub_ip_index)]["externalIP"] if data["networks"][int(pub_ip_index)]["externalIP"] else "null"
        else:
            pub_ip = "null"

        pvmInstanceID = data["pvmInstanceID"] if "pvmInstanceID" in data else "null"
        pvmInstanceID = pvmInstanceID if pvmInstanceID else "null"

        serverName = data["serverName"] if "serverName" in data else "null"
        serverName = serverName if serverName else "null"

        pvmInstanceID = data["pvmInstanceID"] if "pvmInstanceID" in data else "null"
        pvmInstanceID = pvmInstanceID if pvmInstanceID else "null"

        creationDate = data["creationDate"] if "creationDate" in data else "null"
        creationDate = creationDate if creationDate else "null"

        osType = data["osType"] if "osType" in data else "null"
        osType = osType if osType else "null"

        sysType = data["sysType"] if "sysType" in data else "null"
        sysType = sysType if sysType else "null"

        processors = data["processors"] if "processors" in data else 0
        processors = processors if processors else 0

        procType = data["procType"] if "procType" in data else "null"
        procType = procType if procType else "null"

        memory = data["memory"] if "memory" in data else 0
        memory = memory if memory else 0

        health_status = data["health"]["status"] if "health" in data else "null"
        health_status = health_status if health_status else "null"

        status = data["status"] if "status" in data else "null"
        status = status if status else "null"

        vm_values=('{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19}'.format(
            ibmcloud_id,
            ibm_cloud_name,
            pvs_name,
            pvs_zone,
            pvmInstanceID,
            serverName,
            str(creationDate).split("T")[0],
            days_since_creation,
            osType,
            sysType,
            processors,
            procType,
            memory,
            number_volumes_attached,
            total_storage,
            total_tier1,
            total_tier3,
            pub_ip,
            health_status,
            status))
    return vm_values


if __name__ == "__main__":
    vm=sys.argv[1]
    pvs_name=sys.argv[2]
    ibmcloud_id=sys.argv[3]
    ibm_cloud_name=sys.argv[4]
    pvs_zone=sys.argv[5]
    save_data(process_data(vm,pvs_name,ibmcloud_id,ibm_cloud_name,pvs_zone),ibmcloud_id)