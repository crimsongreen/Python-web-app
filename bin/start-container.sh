#!/bin/bash
docker run -d -p 8000:8000 --restart=always --name webserver localhost:5000/python-web-app:v1
