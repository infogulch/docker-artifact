#!/usr/bin/env bash

pushd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null

# Build example image
echo "Rebuilding docker image for example"
printf 'FROM busybox \n RUN mkdir app && echo "Hello World!" > /app/testfile.txt' | docker build -t infogulch/artifact-test - &> /dev/null

# Execute docker artifact to add a label that identifies /app/testfile.txt
../docker-artifact.sh artifact label infogulch/artifact-test /app/testfile.txt

popd &> /dev/null

