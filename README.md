# Docker Artifact

> Use docker image labels to identify which image layer contains a particular file, enabling retrieving just that file (well, the layer the file is in) from the image without needing to download the whole image.

## Setup

### Prerequisites

Requires the `jq` and `curl` programs to be installed on your PATH.

### Installation

Download `docker-artifact.sh` file from this repository and install it at `~/.docker/cli-plugins/docker-artifact` (note the lack of `.sh` suffix) with execute permissions. Validate correct installation by observing the `artifact` command listed in `docker help`.

-OR-

Run the following command in your shell:

```bash
mkdir -p ~/.docker/cli-plugins && \
  curl https://raw.githubusercontent.com/infogulch/docker-artifact/master/docker-artifact.sh > ~/.docker/cli-plugins/docker-artifact && \
  chmod +x ~/.docker/cli-plugins/docker-artifact && \
  docker help | grep artifact > /dev/null && echo "Docker artifact install succeeded!" || echo "Docker artifact install failed :("
```

## Usage

`docker artifact label [image] [file-path-1] [file-path-2] ...`

Adds labels to an existing image enabling the `download` command below to pull just the layers that contain the file paths specified above.

Note: `download` must download the whole layer; to optimize for artifact download size, add the target files to the image in a separate layer.

`docker artifact download [image] [file-path-1] [file-path-2]`

Downloads the image layers associated with the file paths specified and extracts them into the current directory.

## See also

Related to [timwillfixit's original `docker-artifact`](https://github.com/tomwillfixit/docker-artifact) in spirit, though not in history. The primary difference is that this uses a more precice strategy to search for files.

