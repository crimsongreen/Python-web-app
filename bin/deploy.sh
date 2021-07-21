#!/bin/bash

VERSION=${1}

# Deploy infra
cd terraform/ && terraform apply

# Create ECR repo
# aws ecr create-repository --repository-name python-web-app --region eu-west-2

# Get ECR URI endpoint to push docker image to
ECR_REPO=$(aws ecr describe-repositories --region eu-west-2 | grep python-web-app | grep repositoryUri | cut -d ":" -f 2 | tr -d ' ",')

# Retrieve auth token for docker client to access ECR
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin "$ECR_REPO"

# Build image
cd .. && docker build -t python-web-app:"$VERSION" .

# Tag docker image
docker tag python-web-app:"$VERSION" "$ECR_REPO":"$VERSION"

# Push image
docker push "$ECR_REPO":"$VERSION"

# Sleep to allow tasks to be scheduled 
echo ""
echo "Sleeping for 45 seconds to allow tasks to be scheduled"
sleep 45

# Get loadbalancer DNS - Put into browser to see app.
echo ""
ALB=$(aws elbv2 describe-load-balancers --region eu-west-2 | grep frontendlb | grep DNSName | cut -d ":" -f 2 | tr -d ' ",')
echo "Use this URL in the browser to test the app: $ALB"
