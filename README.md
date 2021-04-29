# Docker Artifact

> Use docker image labels to identify which image layer contains a particular file, enabling retrieving just that file (well, the layer the file is in) from the image without needing to download the whole image.

## Setup

### Prerequisites

Requires Docker 19.03 or newer and the `jq` and `curl` programs to be installed on your PATH.

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

`docker artifact` subcommands

* **label**
  
  Usage: `docker artifact label [options] image_name file_paths...`

  Adds a new layer to the end of the existing local image `image_name` with labels indicating in which layer each file from `file_paths` can be found. This enables the `download` subcommand to pull just the layer that contains the desired file without downloading the whole image.

  *Don't forget to push the image after `docker artifact label` completes!*

  Note: The `download` subcommand must download the whole layer; to optimize for artifact download size, add files that will be labeled to the image in a separate layer from other files.

* **download**

  Usage: `docker artifact download [options] image_name file_paths...`

  Queries the remote docker repository api to find labels that indicate which layer to find each file in `file_paths`, then downloads just those layers and extracts `file_paths` from them into the current directory.

Options

* `-v` Prints a verbose description of each operation as the script performs them.

## Example (TODO)

> See the `example/` directory for a complete working example, summarized below:

```
> printf 'FROM busybox \n RUN mkdir app && echo "Hello World!" > /app/testfile.txt' | docker build -t infogulch/test-image -
...
> docker artifact label infogulch/test-image /app/testfile.txt
Successfully added labels to 'infogulch/test-image':
{
  "/app/testfile.txt": "sha256:..."
}
> docker push infogulch/test-image
...
> docker artifact download infogulch/test-image /app/testfile.txt
Downloaded and extracted '/app/testfile.txt' to the current directory
> cat testfile.txt
Hello World!
```

## See also

Related to [timwillfixit's original `docker-artifact`](https://github.com/tomwillfixit/docker-artifact) in spirit, though not in history. Some differences:

* This uses a more precice strategy to find files. Specifically, it searches through layer tars for actual files, where the predecessor only searches through the layer commands for strings that happen to match the specified file names.
* This requires specifying full file paths both to add labels and download. This prevents indadvertently labeling or downloading the wrong file that happens to have the same name.
* This doesn't need to rebuild the docker image from its original Dockerfile & directory context. This means you can add file labels to an existing image built on another machine, and you don't need to recreate the exact `docker build` arugments such as --build-arg, --secret, or --target.
* ???: This doesn't require third-party cli programs such as `ecr` or `az` to connect to cloud-hosted private repositories, it uses `docker login` credentials just like `docker pull` would.
* ???: This correctly handles internal [`.wh.*` "whiteout files"](http://aufs.sourceforge.net/aufs5/man.html) that indicates when a file is deleted. This helps ensure that the file you download is actually present in the final image and wasn't deleted in some later layer. (Note: this is an anti-footgun, of course a malicious actor can still add any label to their image that they want.)

