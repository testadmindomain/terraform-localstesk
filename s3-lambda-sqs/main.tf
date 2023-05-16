
resource "aws_s3_bucket" "bucket" {
  bucket = "app-logs-structured"
}

# create the queue and give the lambda send access

resource "aws_sqs_queue" "alerts_queue" {
  name = "alerts-queue"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:*:*:alerts-queue",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "${aws_lambda_function.func.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_lambda_function" "func" {
  # instead of deploying the lambda from a zip file,
  # we can also deploy it using local code mounting
#  s3_bucket = "__local__"
#  s3_key    = "${path.cwd}/lambda"

  filename      = "lambda.zip"

  function_name = "example_lambda_name"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"
  runtime       = "python3.8"
}


# create an IAM role for the lambda

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}