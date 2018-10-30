#!/bin/bash

set -e

COUNT=$1

# re-create 'jmeter-results' dir
[ -d jmeter-results ] && rm -rf jmeter-results
mkdir -p jmeter-results

# Build base image
docker build -t jmeter-base jmeter-base
# Build master and slave image, run 1 master container and N slaves
docker-compose build \
 && docker-compose up -d --scale master=1 --scale slave=$COUNT

# Find Slave IPs 
SLAVE_IP=$(docker inspect -f '{{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq) | grep slave | awk -F' ' '{print $2}' | tr '\n' ',' | sed 's/.$//')

# Set JMeter WorkDir prefix
JMETER_PREFIX=/jmeter

# Run each jmx-file in 'jmeter-scripts'-dir
# 1. Create subdir in 'results' for each jmeter-test
# 2. cd into it
# 3. Run jmeter-test, so all results will be put in current 'result' dir
for filename in jmeter-scripts/*.jmx; do
    NAME=$(basename $filename)
    NAME="${NAME%.*}"
    eval "docker exec -it master /bin/bash -c '[ -d ${JMETER_PREFIX}/jmeter-results/${NAME} ] || mkdir -p ${JMETER_PREFIX}/jmeter-results/${NAME} \
                                               && cd ${JMETER_PREFIX}/jmeter-results/${NAME} \
                                               && jmeter -n -t ${JMETER_PREFIX}/${filename} -R$SLAVE_IP'"
done

# Add permissions for results
eval "docker exec -it master /bin/bash -c 'chmod -R 777 ${JMETER_PREFIX}/jmeter-results/'"

# Clean containers
docker-compose stop && docker-compose rm -f
