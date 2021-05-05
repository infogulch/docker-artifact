#!/usr/bin/env bash

set -e

function docker_cli_plugin_metadata {
	local vendor="infogulch"
	local version="v0.0.1"
	local description="Manage Artifacts in Docker Images"
	local url="https://github.com/infogulch/docker-artifact"
	printf '{"SchemaVersion":"0.1.0","Vendor":"%s","Version":"%s","ShortDescription":"%s","URL":"%s"}\n' \
		"$vendor" "$version" "$description" "$url"
}

__usage="
Usage: docker artifact [command] [options] [args]
 
Commands:
 
	ls       - List labeled files available to download directly from an image
	download - Download labeled files directly from an image
	label    - Label files in an image 
 
Command usage:
 
	docker artifact ls [options] image_name
	docker artifact download [options] image_name file...
	docker artifact label [options] image_name file...
 
Options:
	-v       - verbose output
	-q       - quiet output
 
Examples:
 
	docker artifact ls infogulch/artifact-test
	docker artifact download infogulch/artifact-test /app/othertestfile.txt
	docker artifact label infogulch/artifact-test /testfile.txt
"

function main {
	case "$1" in
		docker-cli-plugin-metadata)
			docker_cli_plugin_metadata 
			;;
		artifact)
			case "$2" in
				ls|list)
					list "${@:3}"
					;;
				label)
					label "${@:3}"
					;;
				download)
					download "${@:3}"
					;;
				*)
					echo "$__usage"
					;;
			esac
			;;
	esac
}

function list {
	local list="$(list_json "$@" | jq -r 'keys | .[]' | sed 's_^_   _')"
	echo " ** The following files are available to download from $1: "
	echo "$list"
}

function list_json {
	local image="$1"
	local regex='^([-_a-z\.]+)/([-_a-z]+)(:([-_a-z]+))?$'
	if [[ $image =~ $regex ]] ; then
		registry="${BASH_REMATCH[1]}"
		image="${BASH_REMATCH[2]}"
		tag="${BASH_REMATCH[4]:-latest}"
		if ! [[ $registry =~ \. ]] ; then
			image="$registry/$image"
			registry="registry-1.docker.io"
		fi
	else
		echo "Failed to parse image '$image'"
		exit 1
	fi
	local token="$(get_token "$registry" "$image")"
	LOG "Querying manifest to extract labels for '$registry/$image:$tag"
	local manifest="$(curl --silent \
		-H "Accept:application/vnd.docker.container.image.v1+json" \
		-H "Authorization: Bearer $token" \
		"https://$registry/v2/$image/manifests/$tag")"
	local labels="$(jq -r '.history[].v1Compatibility' <<< "$manifest" | jq --slurp -r '[.[].config | select(.Labels != null) | .Labels] | add')"
	jq <<< "$labels"
}

function get_token {
	local registry="$1"
	local image="$2"
	if [[ ! -z "$REGISTRY_TOKEN" ]] ; then
		echo "$REGISTRY_TOKEN"
		return
	fi
	LOG "Retrieving registry token for $registry/$image"
	case "$registry" in
		registry-1.docker.io)
			curl --silent "https://auth.docker.io/token?scope=repository:$image:pull&service=registry.docker.io" \
			| jq -r .token
			;;
		*.azurecr.io)
			echo "$REGISTRY_TOKEN"
			;;
		*.dkr.ecr.*.amazonaws.com)
			aws ecr get-authorization-token | jq -r '.authorizationData[0].authorizationToken'
			;;
	esac
}

function label {
	local image="$1"
	local searchpath="$2"
	local tarfile="$(mktemp).tar"

	# check to see if image exists locally. If not, Docker already prints an error so just exit
	if ! docker image inspect "$image" > /dev/null ; then
		exit 1
	fi

	# Save image tar to temp file
	LOG "Exporting image '$image' to temp file '$tarfile'..."
	docker image save "$image" -o "$tarfile"

	# Set up cleanup to not leave image behind
	trap "delete_files '$tarfile'; trap - RETURN" RETURN

	# Extract manifest and config file contents
	LOG "Collecting metadata from image..."
	local manifest="$(tar -xf "$tarfile" -x manifest.json -O | jq)"
	local config_file="$(echo "$manifest" | jq -r '.[0].Config')"
	local config="$(tar -f "$tarfile" -x "$config_file" -O | jq)"

	# Combine manifest.json and config json to build a map from tar layer directory to layer id sha
	local idmap="$(echo "$manifest" "$config" | jq -s '[ [ .[0][0].Layers, .[1].rootfs.diff_ids ] | transpose[] | { (.[0]): .[1] } ] | reduce .[] as $x ({}; . * $x)')"

	# Search each layer for a file matching $searchpath
	# TODO also search for related whiteout files that start with `.wh.`
	LOG "Searching layers for '$searchpath'..."
	local found="$(echo "$manifest" | jq -r '.[0].Layers[]' | xargs -L1 -I {} bash -c '_search_layer "$@"' _ "$idmap" "$tarfile" {} "$searchpath")"
	local foundcount="$(echo "$found" | grep -c . || true)"

	# If more than one is found, then bail
	if [ $foundcount -gt 1 ]; then
		echo "File was changed in multiple layers, aborting. Found files and layer ids:"
		echo "$found"
		exit 2
	elif [ $foundcount -eq 0 ]; then
		echo "No files found matching '$searchpath'"
		exit 3
	fi

	local labels="$(echo "$found" | sed 's_^.*$_--label "\0"_' | paste -d' ')"

	# Add a layer to the existing image to add the labels and tag the new image with the same image name
	LOG "Rebuilding image and adding labels: $labels"
	echo "FROM $image" | eval docker build $labels -t "$image" - &> /dev/null
	LOG "All image labels:"$'\n'"$(docker image inspect "$image" | jq '.[0].Config.Labels' | sed 's_^_     _' )"

	# Remind user to push image
	echo " ** Rebuilt image '$image' to add $foundcount labels"
	echo " ** Run 'docker push $image' to push it to your container repository"
}

function _search_layer {
	local idmap="$1"
	local imagetar="$2"
	local layertar="$3"
	local search="$4"
	# look up digest associated with layer path
	local digest="$(jq --arg key "$layertar" -r '.[$key]' <<< "$idmap")"
	# extract layer from image | list files in layer | add / prefix | search for file | append =$digest to each found file
	tar -f "$imagetar" -x "$layertar" -O | tar -t | sed s_^_/_ | grep -wx "$search" | sed 's_.$_\0='"$digest"'_'
}

function delete_files {
	LOG "Cleaning up temp files $@"
	rm "$@"
}

export verbose=1
function LOG {
	[ $verbose ] && >&2 echo -e "$(tput setaf 4) => $@$(tput sgr0)"
}

# Export functions used in subshells
export -f LOG
export -f _search_layer

main "$@"

