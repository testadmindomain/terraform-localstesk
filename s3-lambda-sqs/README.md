# Trigger from S3 a log processing Lambda that writes into SQS

## Scenario

* Write a structured log into s3
* Trigger a lambda that processes the logs
* The lambda sends messages to SQS depending on log processing logic

```bash
awslocal s3 cp example-app.log s3://app-logs-structured/example-app-01.log

awslocal sqs receive-message --wait-time-seconds 20 \
	--queue-url http://localhost:4566/000000000000/alerts-queue \
	| jq -r ".Messages[0].Body"

awslocal sqs receive-message --wait-time-seconds 20 \
	--queue-url http://localhost:4566/000000000000/alerts-queue \
	| jq -r ".Messages[0].Body"
```


```
