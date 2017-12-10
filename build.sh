#!/usr/bin/env bash

docker build -t barlock/cloud-media:latest .
docker push barlock/cloud-media:latest
