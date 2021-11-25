# How to run

docker run --rm -v $(pwd)/powervs-data-collector/all-vms/all_vms.csv:/input/all_vms.csv powervs-data-insert:latest /input/all_vms.csv
