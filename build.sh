#!/usr/bin/env bash

docker build -t barlock/cloud-media:ocamlfuse .
docker push barlock/cloud-media:ocamlfuse
