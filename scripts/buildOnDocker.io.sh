#!/bin/bash

USERDOCKER=$1
PROJECT=$2
TAG=$3
docker logout
docker login

docker build $PROJECT/. -t $USERDOCKER/$PROJECT:$TAG
docker tag $PROJECT:$TAG $USERDOCKER/$PROJECT:$TAG
docker push xxx/$PROJECT:$TAG