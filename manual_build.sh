#!/bin/bash

# If you ever need to build the project manually, you can use these commands below.
# This script is not meant to just be run.  Look at the commands and copy/paste them
# as you need them.

# Build the image
podman build . -f Dockerfile -t temp_name

# Run the image on a pod (remove the entry point if you want to just run backstage).
podman run -it --rm --entrypoint /bin/bash localhost/tempname:latest

# Tag the image to something useful and push to docker.io.
podman tag localhost/temp_name:latest docker.io/<your_dockerhub_username>/backstage-for-home:latest
podman push docker.io/<your_dockerhub_username>/backstage-for-home:latest