provider "aws" {
  region = "eu-central-1"
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "scheduled_start_stop_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "scheduled_start_stop_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "scheduled_start_stop" {
  filename         = "lambda-demo3/scheduled_start_stop.zip"
  function_name    = "scheduled_start_stop"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scheduled_start_stop.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.8"
  timeout          = 30
  memory_size      = 128

  # Remove the environment block as we no longer need to pass instance IDs
}

# CloudWatch Event Rule for starting instances
resource "aws_cloudwatch_event_rule" "start_instances" {
  name                = "start-instances"
  #description         = "Start EC2 instances at 8 AM UTC on weekdays"
  #schedule_expression = "cron(0 8 ? * MON-FRI *)"
  description         = "Start EC2 instances in 2 minutes"
  schedule_expression = "rate(2 minutes)"
}

# CloudWatch Event Target for starting instances
resource "aws_cloudwatch_event_target" "start_instances" {
  rule      = aws_cloudwatch_event_rule.start_instances.name
  target_id = "start_instances"
  arn       = aws_lambda_function.scheduled_start_stop.arn
  input     = jsonencode({ "action": "start" })
}

# CloudWatch Event Rule for stopping instances
resource "aws_cloudwatch_event_rule" "stop_instances" {
  name                = "stop-instances"
  #description         = "Stop EC2 instances at 6 PM UTC on weekdays"
  #schedule_expression = "cron(0 18 ? * MON-FRI *)"
  description         = "Stop EC2 instances in 5 minutes"
  schedule_expression = "rate(5 minutes)"
}

# CloudWatch Event Target for stopping instances
resource "aws_cloudwatch_event_target" "stop_instances" {
  rule      = aws_cloudwatch_event_rule.stop_instances.name
  target_id = "stop_instances"
  arn       = aws_lambda_function.scheduled_start_stop.arn
  input     = jsonencode({ "action": "stop" })
}

# Lambda permissions for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_start" {
  statement_id  = "AllowExecutionFromCloudWatchStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled_start_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_instances.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_stop" {
  statement_id  = "AllowExecutionFromCloudWatchStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled_start_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_instances.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda-demo3/scheduled_start_stop.py"
  output_path = "lambda-demo3/scheduled_start_stop.zip"
}

