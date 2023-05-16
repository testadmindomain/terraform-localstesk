#!/usr/bin/env sh

terraform init
terraform plan
terraform apply --auto-approve

# run test
export AWS_PROFILE=localstack
aws --endpoint-url=http://localhost:4566 s3 cp example-app.log s3://app-logs-structured/example-app-01.log

aws --endpoint-url=http://localhost:4566 sqs receive-message --wait-time-seconds 20 --queue-url http://localhost:4566/000000000000/alerts-queue | jq -r ".Messages[0].Body"

aws --endpoint-url=http://localhost:4566 sqs receive-message --wait-time-seconds 20 --queue-url http://localhost:4566/000000000000/alerts-queue | jq -r ".Messages[0].Body"
