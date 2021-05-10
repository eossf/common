#!/bin/bash

PROJECT=$1
TAG=$2
PORT=$3

: ${PORT:=5000}

if [[ $PORT == "" ]] ; then

	echo "3 parameters needed => project tag port"
	echo "Example : ./buildOnK3s.sh memcached latest 5000"
	exit;

fi

docker tag $PROJECT:$TAG localhost:$PORT/$PROJECT:$TAG
docker push localhost:$PORT/$PROJECT:$TAG
# kubectl run $PROJECT --image k3d-local-registry:$PORT/$PROJECT:$TAG