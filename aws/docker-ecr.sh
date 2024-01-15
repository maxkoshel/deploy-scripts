#!/bin/bash

export OLD_IMAGE_TAG=$(docker images --format '{{printf .Tag}}' $REGISTRY/$IMAGE_NAME | head -n 1)
export OLD_CONTAINER_ID=$(docker ps --filter label=$IMAGE_NAME --format '{{printf .ID}}')

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY

docker pull $TAG_COMMIT || true

if [[ -n "$OLD_CONTAINER_ID" ]]; then
  docker stop $IMAGE_NAME > /dev/null
  docker rename $IMAGE_NAME $IMAGE_NAME-old > /dev/null
fi

docker run -d --restart always --env-file .env --name $IMAGE_NAME --label $IMAGE_NAME -p 5000:5000 $TAG_COMMIT

if [ $? -eq 0 ]; then
  if [[ -n "$OLD_CONTAINER_ID" ]]; then
    docker rm $IMAGE_NAME-old
  fi
  if [[ -n "$OLD_IMAGE_TAG" ]]; then
    docker rmi $REGISTRY/$IMAGE_NAME:$OLD_IMAGE_TAG
  fi
  echo "SUCCESS"
else
  docker rmi $TAG_COMMIT > /dev/null
  if [[ -n "$OLD_CONTAINER_ID" ]]; then
    docker rename $IMAGE_NAME-old $IMAGE_NAME
    docker start $IMAGE_NAME
  fi
  echo "FAILURE"
  exit 1
fi
