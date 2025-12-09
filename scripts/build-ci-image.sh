#!/bin/bash
set -e
docker build -f ./Dockerfile -t docker.io/dzr975336710/ci-kaniko-helm:${1:-1.0} .
