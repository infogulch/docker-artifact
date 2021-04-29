#!/usr/bin/env bash

set -e

verbose=1
image="$1"
export searchpath="$2"
export tarfile="$(mktemp)-$image.tar"

# check to see if image exists locally
if ! docker image inspect "$image" > /dev/null ; then
	exit 1
fi

# Save image tar to temp file
[ $verbose ] && >&2 echo "Exporting image '$image' to temp file '$tarfile'..."
docker image save "$image" -o "$tarfile"

# Set up cleanup to not leave image behind
function onexit() {
  [ $verbose ] && >&2 echo "Cleaning up exported image '$tarfile'"
  rm "$tarfile"
}
trap onexit EXIT

# Extract manifest and config file contents
[ $verbose ] && >&2 echo "Collecting metadata from image..."
manifest=$(tar -xf "$tarfile" -x manifest.json -O | jq)
config_file=$(echo "$manifest" | jq -r '.[0].Config')
config=$(tar -f "$tarfile" -x "$config_file" -O | jq)

# Combine manifest.json and config json to build a map from tar layer directory to layer id sha
export idmap=$(echo "$manifest" "$config" | jq -sr '[ [ .[0][0].Layers, .[1].rootfs.diff_ids ] | transpose[] | { (.[0]): .[1] } ] | reduce .[] as $x ({}; . * $x)')

# Search each layer for a file matching $searchpath
# TODO also search for related whiteout files that start with `.wh.`
[ $verbose ] && >&2 echo "Searching layers for '$searchpath'..."
found=$(echo "$manifest" | jq '.[0].Layers[]' | xargs -I {} sh -c 'digest=$(echo "$idmap" | jq -r ".[\"{}\"]"); tar -f "$tarfile" -x {} -O | tar -t | sed s_^_/_ | grep -wx "$searchpath" | xargs -I [] echo "[]=$digest"')

foundcount=$(echo "$found" | grep -c . || true)

# If more than one is found, then bail
if [ $foundcount -gt 1 ]; then
	>&2 echo "File was changed in multiple layers, aborting. Found files and layer ids:"
	>&2 echo "$found"
	exit 2
elif [ $foundcount -eq 0 ]; then
	>&2 echo "No files found matching '$searchpath'"
	exit 3
fi

labels=$(echo "$found" | sed 's_^.*$_--label "\0"_' | paste -d' ')

# Add a layer to the existing image to add the labels and tag the new image with the same image name
[ $verbose ] && >&2 echo "Rebuilding image and adding labels: $labels"
echo "FROM $image" | eval docker build $labels -t "$image" - &> /dev/null

echo "Rebuilt image '$image' with the following added labels:"
docker image inspect "$image" | jq '.[0].Config.Labels'
echo "Run 'docker push $image' to push it to docker hub"

exit

