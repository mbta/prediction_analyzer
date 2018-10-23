#!/bin/bash
set -e -x -u

# bash script should be called with aws environment (dev / dev-green / prod)
# other required configuration:
# * APP
# * DOCKER_REPO
# * ERL_COOKIE
# * SECRET_KEY_BASE

awsenv=$1

# build docker image and tag it with git hash and aws environment
githash=$(git rev-parse --short HEAD)
docker build --build-arg ERL_COOKIE={$ERL_COOKIE} --build-arg SECRET_KEY_BASE={$SECRET_KEY_BASE} -t $APP:latest .
docker tag $APP:latest $DOCKER_REPO/$APP:$awsenv
docker tag $APP:latest $DOCKER_REPO/$APP:git-$githash

# retrieve the `docker login` command from AWS ECR and execute it
logincmd=$(aws ecr get-login --no-include-email --region us-east-1)
eval $logincmd

# push images to ECS image repo
docker push $DOCKER_REPO/$APP:$awsenv
docker push $DOCKER_REPO/$APP:git-$githash
