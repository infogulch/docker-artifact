#!/usr/bin/env bash
set -e

pushd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null

# Build example image
>&2 printf "Rebuilding docker image infogulch/artifact-test\n"
printf 'FROM busybox \n RUN mkdir app && echo "Test data" > /app/testfile.txt && echo "Hello world!" > /hello.txt' | docker build -t infogulch/artifact-test -

>&2 printf "\nLabeling /app/testfile.txt and /hello.txt in infogulch/artifact-test\n"
../docker-artifact.sh artifact label infogulch/artifact-test /app/testfile.txt /hello.txt

>&2 printf "\nPushing image infogulch/artifact-test\n"
docker push infogulch/artifact-test

>&2 printf "\nListing files in infogulch/artifact-test\n"
../docker-artifact.sh artifact ls infogulch/artifact-test

>&2 printf "\nAttempt to download missing file /oops.txt\n"
! ../docker-artifact.sh artifact download infogulch/artifact-test /oops.txt

>&2 printf "\nDownloading /hello.txt and /app/testfile.txt\n"
../docker-artifact.sh artifact download infogulch/artifact-test /hello.txt /app/testfile.txt

popd &> /dev/null

