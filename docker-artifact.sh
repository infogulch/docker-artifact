set -e

verbose=1
image="$1"
export searchpath="$2"
export tarfile="$(mktemp)-$image.tar"

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

# If more than one is found, then bail
if [ $(echo "$found" | wc -l) -gt 1 ]; then
	>&2 echo "Multiple matches found, aborting:"
	>&2 echo "$found"
	exit 2
fi

# print out labels to add during image rebuild
labels=$(echo "$found" | sed 's_^.*$_--label "\0"_' | paste -d' ')

echo "$labels"


[ $verbose ] && >&2 echo "Done!"
exit

