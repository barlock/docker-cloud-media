#!/usr/bin/env bash

docker build -t barlock/cloud-media:rclone .
docker push barlock/cloud-media:rclone
