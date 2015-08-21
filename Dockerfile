# Version 1.0
FROM ubuntu:14.04
MAINTAINER Florian GAUVIN "florian.gauvin@nl.thalesgroup.com"

ENV DEBIAN_FRONTEND noninteractive

#Download all the packages needed

RUN apt-get update && apt-get install -y \
	build-essential \
	uuid-dev \
	cmake \
	git \
	python \
	wget \
	unzip \
	bc\
	uuid-dev \
	language-pack-en \
	curl \
    	libjansson-dev \
    	libxml2-dev \
    	libcurl4-openssl-dev \
        && apt-get clean 

#Download and install the latest version of Docker (You need to be the same version to use this Dockerfile)

RUN wget -qO- https://get.docker.com/ | sh

#Prepare the usr directory by downloading in it : Buildroot, the configuration file of Buildroot and Apache Celix

WORKDIR /usr

RUN wget http://git.buildroot.net/buildroot/snapshot/buildroot-2015.05.tar.gz && \
	tar -xf buildroot-2015.05.tar.gz && \
	git clone https://github.com/florian-gauvin/Buildroot-configure.git --branch celix buildroot-configure-celix && \
	cp buildroot-configure-celix/.config buildroot-2015.05/ && \
	wget https://github.com/apache/celix/archive/develop.tar.gz && \
	tar -xf develop.tar.gz && \
	mkdir celix-build

#Create a small base of the future image with buildroot and decompress it

WORkDIR /usr/buildroot-2015.05

RUN make

WORKDIR /usr/buildroot-2015.05/output/images

RUN tar -xf rootfs.tar &&\
	rm rootfs.tar

#Install etcd

RUN cd /tmp && curl -k -L https://github.com/coreos/etcd/releases/download/v2.0.12/etcd-v2.0.12-linux-amd64.tar.gz | tar xzf - && \
cp etcd-v2.0.12-linux-amd64/etcd /usr/buildroot-2015.05/output/images/bin/ && cp etcd-v2.0.12-linux-amd64/etcdctl /usr/buildroot-2015.05/output/images/bin/

#Add the resources

ADD resources /usr/buildroot-2015.05/output/images/tmp

#Build Celix and link against the libraries in the buildroot environment. It's not a real good way to do so but it's the only one that I have found : I remove the link.txt file and replace it by a one created manually and not during the configuration, otherwise I don't have all the libraries linked against the environment in buildroot

WORKDIR /usr/celix-build

RUN cmake ../celix-develop -DWITH_APR=OFF -DCURL_LIBRARY=/usr/buildroot-2015.05/output/images/usr/lib/libcurl.so.4 -DZLIB_LIBRARY=/usr/buildroot-2015.05/output/images/usr/lib/libz.so.1 -DUUID_LIBRARY=/usr/buildroot-2015.05/output/images/usr/lib/libuuid.so -DBUILD_SHELL=TRUE -DBUILD_SHELL_TUI=TRUE -DBUILD_REMOTE_SHELL=TRUE -DBUILD_DEPLOYMENT_ADMIN=ON -DCMAKE_INSTALL_PREFIX=/usr/buildroot-2015.05/output/images/usr && \
	rm -f /usr/celix-build/launcher/CMakeFiles/celix.dir/link.txt && \
	echo "/usr/bin/cc  -D_GNU_SOURCE -std=gnu99 -Wall  -g CMakeFiles/celix.dir/private/src/launcher.c.o  -o celix -rdynamic ../framework/libcelix_framework.so /usr/buildroot-2015.05/output/images/lib/libpthread.so.0 /usr/buildroot-2015.05/output/images/lib/libdl.so.2 /usr/buildroot-2015.05/output/images/lib/libc.so.6 /usr/buildroot-2015.05/output/images/usr/lib/libcurl.so.4 ../utils/libcelix_utils.so -lm /usr/buildroot-2015.05/output/images/usr/lib/libuuid.so /usr/buildroot-2015.05/output/images/usr/lib/libz.so.1" > /usr/celix-build/launcher/CMakeFiles/celix.dir/link.txt && \
	make all && \
	make install-all 

# Create the config.properties file that celix will need in the futur small docker image

RUN echo "cosgi.auto.start.1= /usr/share/celix/bundles/deployment_admin.zip /usr/share/celix/bundles/log_service.zip /usr/share/celix/bundles/log_writer.zip /usr/share/celix/bundles/remote_shell.zip /usr/share/celix/bundles/shell.zip /usr/share/celix/bundles/shell_tui.zip" > /usr/buildroot-2015.05/output/images/usr/bin/config.properties


#We have all we need for the futur image so we can compress all the files
WORKDIR /usr/buildroot-2015.05/output/images

RUN tar -cf rootfs.tar *

#When the builder image is launch, it creates the celix docker image that you will be able to see by running the command : docker images

ENTRYPOINT for i in `seq 0 100`; do sudo mknod -m0660 /dev/loop$i b 7 $i; done && \
	service docker start && \
	docker import - inaetics/celix-agent < rootfs.tar &&\
	/bin/bash 
