# MIT License

# Copyright (c) 2023 Emanuele Giona

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#/bin/bash

if [[ -z "$INPUT_NS3_DOCKER_IMG" ]]; then
    echo "Error: no Docker image provided"
    exit 1
fi

if [[ -z "$INPUT_TEST_SCRIPT" ]]; then
    echo "Error: no installation & testing script provided"
    exit 1
fi

# Create entrypoint.sh script for later usage within Docker container
cat >entrypoint.sh <<'EOL'
#!/bin/bash

cd /home
# Unpack contents of current repository's root directory
ARCHIVE_NAME="${ROOT_REPO_DIR}.tar.gz"
tar -xf "/home/${ARCHIVE_NAME}"

# Run user-provided installation & testing script
cd "${ROOT_REPO_DIR}" && . "${TEST_SCRIPT}" && \
exit 0
EOL
chmod +x entrypoint.sh

# Fetch the specified Docker image
OUTCOME=1
docker pull $INPUT_NS3_DOCKER_IMG && OUTCOME=0

if [[ "$OUTCOME" -eq 1 ]]; then
    echo "Error: docker pull ${INPUT_NS3_DOCKER_IMG} failed"
    exit 1
fi

# Prepare user module repository contents for their copy into a container
REPO_DIR="ns3-module-repo"
shopt -s extglob
mkdir "$REPO_DIR"
cp -r !("$REPO_DIR") "$REPO_DIR/"
tar -cf "$REPO_DIR.tar.gz" "$REPO_DIR"

# Start a container from the specific image
OUTCOME=1
CONTAINER_NAME="ns3-container"
docker run \
 -e ROOT_REPO_DIR="${REPO_DIR}" \
 -e TEST_SCRIPT="${INPUT_TEST_SCRIPT}" \
 -td \
 --name "$CONTAINER_NAME" "$INPUT_NS3_DOCKER_IMG" && OUTCOME=0

if [[ "$OUTCOME" -eq 1 ]]; then
    echo "Error: docker run ${INPUT_NS3_DOCKER_IMG} failed"
    exit 1
fi

# Copy entryscript and repository contents into the container
docker cp entrypoint.sh "$CONTAINER_NAME:/home/entrypoint.sh"
docker cp "$REPO_DIR.tar.gz" "$CONTAINER_NAME:/home/"

# Finally execute the installation & testing script
OUTCOME=1
docker exec "$CONTAINER_NAME" "./home/entrypoint.sh" && OUTCOME=0

if [[ "$OUTCOME" -eq 1 ]]; then
    echo "Error: docker exec failed"
    exit 1
fi

# Parse execution & test outputs
docker cp "$CONTAINER_NAME:/home/exit-code.txt" ./exit-code.txt
docker cp "$CONTAINER_NAME:/home/test-output.txt" ./test-output.txt
OUTCOME=$(cat exit-code.txt)

# Cleanup Docker container
docker kill "$CONTAINER_NAME" && \
docker rm "$CONTAINER_NAME"

if [[ "$OUTCOME" -eq 0 ]]; then
    echo "Action completed successfully"
    echo "result=success" >> "$GITHUB_OUTPUT"
else
    echo "Action failed"
    echo "result=failure" >> "$GITHUB_OUTPUT"
fi

echo "=== Test outputs ==="
cat test-output.txt
echo "=== ===== ===== ==="
exit $OUTCOME
