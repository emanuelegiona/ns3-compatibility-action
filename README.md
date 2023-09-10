# ns3-compatibility-action
Custom GitHub Action for testing one or more modules against a specific [ns-3][ns3] version.

## Rationale

The development of ns-3 is an effort by large community, with both the base simulator and third-party modules evolving at a fast pace.
This is the result of ns-3 being widely used in research performed at both industry and academia worldwide.

This GitHub action aims at supporting the development of new modules, ensuring compatibility guarantees against multiple ns-3 versions by leveraging CI/CD pipelines.

## Usage guidelines

**Inputs**

- `ns3_docker_img` (**Required**)

    [Docker][docker] image in the format _name:tag_ containing an installation of the desired ns-3 version to test against.

    *Image requirements*

    - Existence of a `/home` directory in resulting containers

    - `bash` shell support

    - `tar` package availability

    - Refrain from using `ns3-container` as Docker container name within a same action runner

    > Any Docker image available to the action runner is supported.

    > A useful selection of images spanning across several ns-3 versions is found at [egiona/ns3-woss][ns3-woss-docker]. These images provide _already-built_ ns-3 installations bundling the [World Ocean Simulation System][woss] library, as well as some utility scripts.
    Being pre-built in _debug_ profile, these images greatly reduce the testing time for your module(s).

- `test_script` (**Required**)

    Path to an installation & testing bash script, relatively to the _root of the action-invoking repository_.

    *Script requirements*

    - This script should perform any installation step required by the modules intended to be tested, and optionally run the desired test suite(s)

    - Creation of a file at container's path `/home/exit-code.txt` ; this file should consist in either `0` or `1`, respectively indicating a successful installation & testing or not

    - Creation of a file at container's path `/home/test-output.txt` ; this file should consist of a textual message to print as an additional explanation to tests' outcome (_i.e._ it can be empty, but it is necessary nonetheless)

    - This script should \_NOT\_ contain the final `exit` bash instruction as to avoid unintended failures of `docker exec` ; exit status should be reported by means of the `/home/exit-code.txt` file

    > This script is run inside the container created from the provided image.
    Contents of the repository this action is invoked from are copied as a compressed archive at container's path `/home/ns3-module-repo.tar.gz` and then unpacked.
    This argument should thus point at _source-able_ bash script within  container's directory `/home/ns3-module-repo/`.

**Outputs**

- `result`

    Values: `success` | `failure`

    Storage: `$GITHUB_OUTPUT`

## Workflow example

Testing a module `my-module` for ns-3 compatibility against versions 3.33 and 3.37 after each tag is pushed to the repository.
Docker images employed are [`egiona/ns3-woss:u18.04-n3.33-w1.12.1-r2`][img3.33] and [`egiona/ns3-woss:u18.04-n3.37-w1.12.4-r2`][img3.37], respectively.

Repository structure:
```
my-module/
    doc/
        ...
    examples/
        ...
    helper/
        ...
    model/
        ...
    test/
        ...
    CMakeLists.txt
    wscript
test-ns3.sh
```

`check-compatibility.yml` file:
```
on:
  push:
    tags:
      - '*'

jobs:
  ns3_33_check:
    runs-on: ubuntu-latest
    name: ns-3.33 compatibility check
    steps:
      - name: ns3-compatibility-action
        uses: emanuelegiona/ns3-compatibility-action@v1
        with:
          ns3_docker_img: egiona/ns3-woss:u18.04-n3.33-w1.12.1-r2
          test_script: test-ns3.sh
  ns3_37_check:
    runs-on: ubuntu-latest
    name: ns-3.37 compatibility check
    steps:
      - name: ns3-compatibility-action
        uses: emanuelegiona/ns3-compatibility-action@v1
        with:
          ns3_docker_img: egiona/ns3-woss:u18.04-n3.37-w1.12.4-r2
          test_script: test-ns3.sh
```

`test-ns3.sh` file:
```
#!/bin/bash

# Prepare output files
OUTCOME=1
echo "${OUTCOME}" > /home/exit-code.txt
echo "my-module-test: Test not run" > /home/test-output.txt

# Install module into ns-3 "contrib" tree using the Makefile (assumption: working directory is the same as this file)
OUTCOME=1
cp -r my-module /home/
cd /home

# Ensure debug profile _before_ copying module
export NS3_CURR_PROFILE=${NS3_DEBUG_DIR}
make sync_module FILE=my-module

# Necessary to avoid killing docker parent processes (build scripts send USR1 signal in interactive shells)
trap "echo Ignoring USR1" USR1
./build-debug.sh && OUTCOME=0

if [[ "$OUTCOME" -eq 1 ]]; then
    echo "Error: build failed"
else
    # Run module-specific tests and retain their outputs
    OUTCOME=1
    make test SUITE=my-module-test LOG=/home/test-tmp && \
    OUTCOME=0

    if [[ "$OUTCOME" -eq 1 ]]; then
        echo "Error: tests failed"
    fi
fi

# Update "test-output.txt" with tests execution details
cat /home/test-tmp.txt > /home/test-output.txt

# Only return success if all previous commands executed correctly
echo "${OUTCOME}" > /home/exit-code.txt

# === No exit here ===
# Avoids exiting the entrypoint sub-script from GitHub action that sources this file
```
> Note: this `test-ns3.sh` script applies to the employed Docker images only, and assuming an implemented ns-3 test suite named `my-module-test`.

## License

**Copyright (c) 2023 Emanuele Giona**

This repository, scripts and snippets themselves are distributed under [MIT license][license].

**Diclaimer: Docker, Ubuntu, ns-3, WOSS and other cited or included software belongs to their respective owners.**



[ns3]: https://www.nsnam.org/
[ns3-changelog]: https://gitlab.com/nsnam/ns-3-dev/-/blob/master/CHANGES.md
[docker]: https://www.docker.com/
[ns3-woss-docker]: https://github.com/SENSES-Lab-Sapienza/ns3-woss-docker
[woss]: https://woss.dei.unipd.it/
[img3.33]: https://github.com/SENSES-Lab-Sapienza/ns3-woss-docker/blob/main/u18.04-n3.33-w1.12.1-r2/Dockerfile
[img3.37]: https://github.com/SENSES-Lab-Sapienza/ns3-woss-docker/blob/main/u18.04-n3.37-w1.12.4-r2/Dockerfile
[license]: ./LICENSE
