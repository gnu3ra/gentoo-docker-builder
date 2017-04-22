Docker image builder for Gentoo stages
======================================

This is largely a helper tool for producing base images for Docker containers
using musl-libc Gentoo stages.  `mkimg.sh` takes a number of arguments on the
command line:

```
$ sh mkimg.sh STAGE3 SNAPSHOT DOCKER_REPO DOCKER_BASENAME DOCKER_TAG
```

where:

* `STAGE3`: is the path to a stage 3 tarball
* `SNAPSHOT`: is a portage tree snapshot
* `DOCKER_REPO`: is the name of your docker repository or local registry
* `DOCKER_BASENAME`: is the name that will be prefixed to the names of all
  containers built.
* `DOCKER_TAG`: is the tag applied to the generated docker images.

In the current working directory, it will create the directories:

* `packages/${TAG}`: The binary package directory
* `portage/${TAG}`: The portage tree snapshot directory

`mkimg.sh` then imports the stage 3 tarball into a "raw" container which is
used as an ephemeral build environment, the image will be tagged
`${DOCKER_REPO}/${DOCKER_BASENAME}-raw:${DOCKER_TAG}`.

Having imported that, a docker container is launched, in privileged mode (some
packages will not build without) and `mkimg-container.sh` runs.

`mkimg-container.sh` rebuilds the entire system, doing an `emerge -e @system
@world` to populate the binary packages.  This step can also be adjusted to
set `USE` flags as desired.

It then populates two staging directories:
* `${BASENAME}-dev-${TAG}` is populated with all packages
* `${BASENAME}-rt-${TAG}` is populated with only run-time packages

These are then packaged up as `.tar` files.

`mkimg.sh` takes over at this point, imports the two `tar`s as docker images
and publishes them.

Container usage
===============

There are two containers produced by this that are intended for actual use.
The `dev` container is used for building binaries.  It has the full Gentoo
suite available.

The `rt` container only contains the run-time environment.  There's no
compilers, and only minimal support packages.  Portage works for merging
binary packages produced by the development (`dev`) container.

The installation procedure is to use `docker run` with the `dev` container to
compile your binary packages.  In the absence of `docker build -v` support
(see [Docker bug
\#14080](https://github.com/docker/docker/issues/14080#issuecomment-288361192)),
I suggest this approach:

```
$ docker run --rm -v /usr/portage:/usr/portage \
	-v packages:/usr/portage/packages \
	myrepo/baseimage-dev:tag emerge www-servers/apache
$ docker run --name my-temp-apache-container --rm -v /usr/portage:/usr/portage \
	-v packages:/usr/portage/packages \
	myrepo/baseimage-rt:tag emerge -K www-servers/apache
$ docker commit my-temp-apache-container my-temp-apache-image
```

… then use that image with a `Dockerfile` to do final customisations.

In doing this, we do not pollute the target container with build-time
dependencies and thus keep it as small as possible.
