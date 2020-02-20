#!/usr/bin/env bash

export REGISTRY=adhubtest.azurecr.io
export OPENJDK=openjdk-11.0.2_linux-x64_bin.tar.gz

export BRANCH_NAME=0.1

if [ "$#" -ge 1 ]; then
    BRANCH_NAME=$1
fi

if [ "$#" -ge 2 ]; then
    IMAGE_TAG=$2
else 
    IMAGE_TAG=${BRANCH_NAME}
fi

export IMAGE_TAG

if [ ! -f "$OPENJDK" ]; then
    curl -o "${OPENJDK}" "https://download.java.net/java/GA/jdk11/9/GPL/${OPENJDK}"
fi

if [ -d "fff-og-0.3.9" ]; then
	cd fff-og-0.3.9
	git pull
	cd ..
else
	git clone ssh://git@git.funptw:2222/funP/fff-og.git -b 0.3.9 fff-og-0.3.9
fi


docker build . --build-arg OPENJDK=$OPENJDK --build-arg BRANCH_NAME=$BRANCH_NAME -t $REGISTRY/acho:$IMAGE_TAG

# docker run -p 127.0.0.1:80:80 -it kelly4286/acho:0.1

# docker push adhubtest.azurecr.io/acho:0.1
