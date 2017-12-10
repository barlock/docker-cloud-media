#!/usr/bin/env bash

docker build -t barlock/cloud-media:decrypt .
docker push barlock/cloud-media:decrypt
