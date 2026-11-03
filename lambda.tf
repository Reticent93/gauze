data "archive_file" "redactor" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "redactor" {
  name = "gauze-redactor"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "redactor-logs" {
  role = aws_iam_role.redactor.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadOriginalObjects"
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${aws_s3_access_point.phi-origin.arn}/object/*"
      },
      {
        Sid      = "ListForAccurate404s"
        Effect   = "Allow"
        Action   = "s3:listBucket"
        Resource = aws_s3_access_point.phi-origin.arn
      },
      {
        Sid      = "DecryptPHIObjects"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.phi_key.arn
      },
      {
        Sid      = "DetectPHI"
        Effect   = "Allow"
        Action   = "comprehendmedical:DetectPHI"
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "redactor" {
  name              = "/aws/lambda/gauze-redactor"
  retention_in_days = 14
}

resource "aws_lambda_function" "redactor" {
  function_name    = "gauze-redactor"
  role             = aws_iam_role.redactor.arn
  handler          = handler.lambda_handler
  timeout          = 60
  memory_size      = 512
  runtime          = "python3.12"
  filename         = data.archive_file.redactor.output_path
  source_code_hash = data.archive_file.redactor.output_base64sha256

  environment {
    variables = {
      SUPPORTING_AP_ARN = aws_s3_access_point.phi-origin.arn
      TRANSFORM_MODE    = "redact"
    }
  }
  depends_on = [aws_cloudwatch_log_group.redactor]
}

resource "aws_lambda_function_url" "redactor" {
  authorization_type = "AWS_IAM"
  function_name      = aws_lambda_function.redactor.function_name
}

resource "aws_lambda_permission" "redactor" {
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.redactor.function_name
  principal     = aws_iam_role.analyst.arn
}