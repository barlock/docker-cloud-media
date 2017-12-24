####################
# BASE IMAGE
####################
FROM ubuntu:16.04

MAINTAINER barlockm@gmail.com <barlockm@gmail.com>

####################
# INSTALLATIONS
####################
RUN apt-get update && apt-get install -y \
    curl \
    fuse \
    unionfs-fuse \
    encfs \
    wget

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates && apt-get install -y openssl
RUN sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

# MongoDB 3.4
RUN \
   apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 && \
   echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list && \
   apt-get update && \
   apt-get install -y mongodb-org

# Plexdrive 4

ENV PLEXDRIVE_BIN="plexdrive-linux-amd64"
ENV PLEXDRIVE_URL="https://github.com/dweidenfeld/plexdrive/releases/download/4.0.0/${PLEXDRIVE_BIN}"

RUN \
    wget "$PLEXDRIVE_URL" && \
    chmod a+x "$PLEXDRIVE_BIN" && \
    cp -rf "$PLEXDRIVE_BIN" "/usr/bin/plexdrive" && \
    rm -rf "$PLEXDRIVE_BIN"

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

# Plexdrive
ENV CHUNK_SIZE "10M"
ENV CLEAR_CHUNK_MAX_SIZE ""
ENV CLEAR_CHUNK_AGE "24h"
ENV LOG_LEVEL "3"
ENV MONGO_DATABASE "plexdrive"

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
VOLUME /data/db /config /cloud-encrypt /cloud-decrypt /union /local-media /local-encrypt /chunks /log

RUN chmod -R 777 /data
RUN chmod -R 777 /log

####################
# WORKING DIRECTORY
####################
WORKDIR /data

####################
# ENTRYPOINT
####################
ENTRYPOINT ["/init"]