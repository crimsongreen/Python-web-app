#!/bin/bash

VERSION=${1}

echo Beginning build of $VERSION

docker build -t python-web-app:$VERSION .
docker tag python-web-app:$VERSION localhost:5000/python-web-app:$VERSION
docker push localhost:5000/python-web-app:$VERSION
