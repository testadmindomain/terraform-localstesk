resource "aws_api_gateway_rest_api" "rest" {
  name = "AWS Lambda"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_rest_api.rest.root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  type                    = "AWS"
  rest_api_id             = aws_api_gateway_rest_api.rest.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"

  uri = aws_lambda_function.lambda.invoke_arn

  request_templates = {
    "application/json" = "#set($allParams = $input.params())\n{\n\"body-json\" : $input.json(\"$\"),\n\"params\" : {\n#foreach($type in $allParams.keySet())\n    #set($params = $allParams.get($type))\n\"$type\" : {\n    #foreach($paramName in $params.keySet())\n    \"$paramName\" : \"$util.escapeJavaScript($params.get($paramName))\"\n        #if($foreach.hasNext),#end\n    #end\n}\n    #if($foreach.hasNext),#end\n#end\n},\n\"stage-variables\" : {\n#foreach($key in $stageVariables.keySet())\n\"$key\" : \"$util.escapeJavaScript($stageVariables.get($key))\"\n    #if($foreach.hasNext),#end\n#end\n},\n\"context\" : {\n    \"api-id\" : \"$context.apiId\",\n    \"api-key\" : \"$context.identity.apiKey\",\n    \"http-method\" : \"$context.httpMethod\",\n    \"stage\" : \"$context.stage\",\n    \"source-ip\" : \"$context.identity.sourceIp\",\n    \"user-agent\" : \"$context.identity.userAgent\",\n    \"request-id\" : \"$context.requestId\",\n    \"resource-id\" : \"$context.resourceId\",\n    \"resource-path\" : \"$context.resourcePath\"\n    }\n}\n"
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

resource "aws_lambda_function" "lambda" {
  filename      = "apigw-lambda/lambda.zip"
  function_name = "mylambda"
  role          = aws_iam_role.role.arn
  handler       = "lambda.handler"

  source_code_hash = filebase64sha256("apigw-lambda/lambda.zip")

  runtime = "nodejs12.x"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

resource "aws_iam_role" "role" {
  name = "myrole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}
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

  filename      = "sqs+lambda+s3/lambda.zip"

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
resource "aws_api_gateway_integration_response" "integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" : "'*'",
    "method.response.header.Content-Type" : "'text/html'"
  }

  response_templates = {
    "text/html" : "$input.path('$')"
  }
}