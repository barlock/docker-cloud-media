####################
# BASE IMAGE
####################
FROM ubuntu:18.04

MAINTAINER barlockm@gmail.com <barlockm@gmail.com>

####################
# INSTALLATIONS
####################
RUN apt-get update && apt-get install -y \
    curl \
    fuse \
    unionfs-fuse \
    encfs \
    wget \
    software-properties-common

RUN apt-get install -y ca-certificates && update-ca-certificates && apt-get install -y openssl
RUN sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

# google-drive-ocamlfuse
RUN add-apt-repository ppa:alessandro-strada/ppa && \
    apt-get update && \
    apt-get install -y google-drive-ocamlfuse

# S6 overlay
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

RUN \
    OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    curl -o \
    /tmp/s6-overlay.tar.gz -L \
    "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" && \
    tar xfz \
    /tmp/s6-overlay.tar.gz -C /


####################
# ENVIRONMENT VARIABLES
####################

# Drive Config
ENV LOCAL_DRIVE "1"
ENV REMOTE_DRIVE "1"
ENV REMOTE_PROVIDED "0"

# Time format
ENV DATE_FORMAT "+%F@%T"

####################
# SCRIPTS
####################
COPY setup/* /usr/bin/

COPY scripts/* /usr/bin/

RUN chmod a+x /usr/bin/*

COPY root /

# Create abc user
RUN groupmod -g 1000 users && \
	useradd -u 911 -U -d / -s /bin/false abc && \
	usermod -G users abc

####################
# VOLUMES
####################
# Define mountable directories.
VOLUME /config /cloud-encrypt /cloud-decrypt /union /local-media /local-encrypt /log

RUN chmod -R 777 /config
RUN chmod -R 777 /log

####################
# WORKING DIRECTORY
####################
WORKDIR /data

####################
# ENTRYPOINT
####################
ENTRYPOINT ["/init"]
