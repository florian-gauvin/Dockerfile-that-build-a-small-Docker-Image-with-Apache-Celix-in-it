# Version 1.0
FROM ubuntu:14.04
MAINTAINER Florian GAUVIN "florian.gauvin@nl.thalesgroup.com"

ENV DEBIAN_FRONTEND noninteractive

#Download all the packages needed 

RUN apt-get update && apt-get install -y \
	build-essential \
	cmake \
	git \
	python \
	wget \
	unzip \
	bc\
	language-pack-en \
        && apt-get clean 

#Download and install the latest version of Docker (You need to be the same version to use this Dockerfile)

RUN wget -qO- https://get.docker.com/ | sh

#Clone a complete buildroot environment pre-configured with a celix package

RUN git clone https://github.com/florian-gauvin/Buildroot-Celix.git /usr/buildroot

#Build the small tar file with celix in it

WORKDIR /usr/buildroot

RUN make

#When the builder image is launch, it creates the celix docker image that you will be able to see by running the command : docker images

ENTRYPOINT for i in `seq 0 100`; do sudo mknod -m0660 /dev/loop$i b 7 $i; done && \
	service docker start && \
	docker import - celix.image < /usr/buildroot/output/images/rootfs.tar &&\
	/bin/bash 


