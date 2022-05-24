# ECS canary (Blue/Green) deployment with AWS CodeDeploy
Terraform project to provision resources for a customized Amazon ECS canary (Blue/Green) deployment using AWS CodeDeploy

### Random notes

Manual build commands:

`aws ecr get-login-password | docker login --username AWS --password-stdin $REPOSITORY_URI`

Get hash:

`COMMIT_HASH=(git rev-parse HEAD | cut -c 1-7)`
`IMAGE_TAG=${COMMIT_HASH:=latest}`

Build:
`docker build -t $REPOSITORY_URI:latest -t $REPOSITORY_URI:$IMAGE_TAG .`

Push to ECR:
`docker push $REPOSITORY_URI:latest`
`docker push $REPOSITORY_URI:$IMAGE_TAG`

Then, **Update the task definition**
