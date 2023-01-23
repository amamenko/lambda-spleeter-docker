# lambda-spleeter-docker 

This repo can be built to create an image (3.35G uncompressed, 1.31G compressed) that can be used to run Spleeter, FFMPEG, and Python 3.7 on an AWS Lambda function. It comes pre-built with Spleeter's 2 stem pretrained models to split an input audio track into accompaniment and vocal output tracks.

## Getting Started:

1. Run `git clone https://github.com/amamenko/lambda-spleeter-docker.git` to clone this repo locally.
2. Build the image locally with Docker and push to a private repository in your AWS Elastic Container Registry (ECR):
      - Create a private repository in your AWS ECR. 
      - Using the AWS CLI, acquire an authentication token and authenticate your Docker client to your registry: `aws ecr get-login-password --region [YOUR REGION] | docker login --username AWS --password-stdin xxx.ecr.[YOUR REGION].amazonaws.com`
      - Build the docker image locally: `docker build -t lambda-spleeter-docker .`
      - Tag the built image: `docker tag lambda-spleeter-docker:latest xxx.ecr.[YOUR REGION].amazonaws.com/lambda-spleeter-docker:latest`
      - Push the local image to your private AWS ECR repository: `docker push xxx.ecr.[YOUR REGION].amazonaws.com/lambda-spleeter-docker:latest`
3. Deploy a new Lambda function using the container image URI from the pushed image within your private AWS ECR repository.

## Lambda Set Up
1. OPTIONAL: You can set up an AWS EventBridge Cloudwatch Event rule to ping your lambda function (e.g. every 5 minutes) to keep it warm. This rule should send the following as a constant JSON parameter to be consumed by [lambda-warmer-py](https://github.com/robhowley/lambda-warmer-py):
```json
{
  "warmer": true,
  "concurrency": 1
}
```
2. Set up an S3 trigger on your Lambda function using an S3 input audio bucket so that it is invoked when audio is uploaded to that bucket.
3. In your Lamda's environment variables section, you can set `OUTPUT_BUCKET` to the name of the S3 output bucket that you would like the split accompaniment and vocals output tracks to be uploaded to when Spleeter is done processing the input audio. You can also set the `OUTPUT_FILENAME_FORMAT` to how you would like the output filenames to be formatted (e.g. `{filename}_{instrument}.{codec}`).
