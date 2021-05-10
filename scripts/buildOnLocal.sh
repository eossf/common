#!/bin/bash

echo "Example : ./buildLocal.sh memcached latest"

PROJECT=$1
TAG=$2

docker build ../BUILD/$PROJECT/. -t $PROJECT:$TAG