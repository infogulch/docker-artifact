#!/usr/bin/env bash
set -e

source=$(dirname "${BASH_SOURCE[0]}")
pushd "$source" &> /dev/null

# Build example image
docker build . -t test-image &> /dev/null

# Execute docker artifact to add a label to /app/othertestfile.txt
set +e
../docker-artifact.sh test-image /app/othertestfile.txt

popd &> /dev/null

