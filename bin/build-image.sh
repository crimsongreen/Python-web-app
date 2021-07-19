#!/bin/bash

VERSION=${1}

echo Beginning build of $VERSION

docker build -t python-web-app:$VERSION .
docker tag python-web-app:v1 localhost:5000/python-web-app:$VERSION
docker push localhost:5000/python-web-app:$VERSION
