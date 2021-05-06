#!/usr/bin/env bash

pushd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null

# Build example image
echo "Rebuilding docker image infogulch/artifact-test"
printf 'FROM busybox \n RUN mkdir app && echo "Hello World!" > /app/testfile.txt' | docker build -t infogulch/artifact-test -

# Execute docker artifact to add a label that identifies /app/testfile.txt
echo ""
echo "Labeling /app/testfile.txt in infogulch/artifact-test"
../docker-artifact.sh artifact label infogulch/artifact-test /app/testfile.txt

echo ""
echo "Pushing image infogulch/artifact-test"
docker push infogulch/artifact-test

echo ""
echo "Listing files in infogulch/artifact-test"
../docker-artifact.sh artifact ls infogulch/artifact-test

popd &> /dev/null

