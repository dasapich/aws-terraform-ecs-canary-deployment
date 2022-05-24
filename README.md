# ECS canary (Blue/Green) deployment with AWS CodeDeploy
Terraform project to provision resources for a customized Amazon ECS canary (Blue/Green) deployment using AWS CodeDeploy

### Random notes

Manual build commands:

`aws ecr get-login-password | docker login --username AWS --password-stdin $REPOSITORY_URI`

Get hash:

`COMMIT_HASH=(git rev-parse HEAD | cut -c 1-7)`
`IMAGE_TAG=${COMMIT_HASH:=latest}`

Build:
`docker build -t ecs-canary-demo .`
`docker tag ecs-canary-demo:latest $REPOSITORY_URI:$IMAGE_TAG`

Push to ECR:
`docker push $REPOSITORY_URI:latest`
`docker push $REPOSITORY_URI:$IMAGE_TAG`

Then, **Update the task definition**

#### Zip lambda functions
```
cd lambda_functions
zip -r ../before_install.zip before_install.py
zip -r ../after_allow_test_traffic.zip after_allow_test_traffic.py
zip -r ../before_allow_traffic.zip before_allow_traffic.py
```

#### Deploy new version
```
{
    "applicationName": "tutorial-bluegreen-app",
    "deploymentGroupName": "tutorial-bluegreen-dg",
    "revision": {
        "revisionType": "S3",
        "s3Location": {
            "bucket": "tutorial-bluegreen-bucket",
            "key": "appspec.yaml",
            "bundleType": "YAML"
        }
    }
}
```

```
aws deploy create-deployment \
     --cli-input-json file://create-deployment.json \
     --region us-east-1
```
