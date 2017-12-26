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
    wget \
    unzip

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates && apt-get install -y openssl
RUN sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

# Rclone
ENV RCLONE_VERSION="current"
ENV PLATFORM_ARCH="amd64"

RUN cd tmp && \
  wget -q http://downloads.rclone.org/rclone-${RCLONE_VERSION}-linux-${PLATFORM_ARCH}.zip && \
  unzip /tmp/rclone-${RCLONE_VERSION}-linux-${PLATFORM_ARCH}.zip && \
  mv /tmp/rclone-*-linux-${PLATFORM_ARCH}/rclone /usr/bin


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

# Rclone
ENV BUFFER_SIZE "500M"
ENV MAX_READ_AHEAD "30G"
ENV CHECKERS "16"
ENV TPS_LIMIT "10"
ENV RCLONE_CLOUD_ENDPOINT "gdrive:"
ENV CACHE_MODE "minimal"

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