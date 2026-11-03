locals {
  trusted_principal = var.trusted_principal_arn
}

data "aws_iam_policy_document" "assumed_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.trusted_principal]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "analyst" {
  name               = "gauze-analyst"
  assume_role_policy = data.aws_iam_policy_document.assumed_role
}

resource "aws_iam_role_policy" "analyst" {
  name = "gauze-analyst-inline"
  role = aws_iam_role.analyst.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeLambdaFuntionUrl"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunctionUrl"
        Resource = aws_lambda_function.redactor.arn
        Condition = {
          StringEquals = { "lambda:FunctionUrlAuthType" = "AWS_IAM" }
        }
      },
      {
        Sid      = "DecryptForTransform"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.phi_key.arn
      },
    ]
  })
}

resource "aws_iam_role" "privileged" {
  name               = "gauze-privileged"
  assume_role_policy = data.aws_iam_policy_document.assumed_role.json
}

resource "aws_iam_role_policy" "privileged" {
  name = "gauze-privileged-inline"
  role = aws_iam_role.privileged.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadFullPHIThroughAccessPoint"
      Effect   = "Allow"
      Action   = "s3:GetObject"
      resource = "${aws_s3_access_point.phi-origin.arn}/object/*"
      },
      {
        Sid      = "DecryptPHIObjects"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.phi_key.arn
      }
    ]

  })
}

resource "aws_iam_role" "break_glass" {
  name               = "gauze-break-glass"
  assume_role_policy = data.aws_iam_policy_document.assumed_role.json
}

resource "aws_iam_role_policy" "break_glass" {
  name = "gauze-break-glass-inline"
  role = aws_iam_role.break_glass.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadFullPHIThroughAccessPoint"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:GetObjectVersion"]
      Resource = "${aws_s3_access_point.phi-origin.arn}/object/*"
      },
      {
        Sid      = "DecryptPHIObjects"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.phi_key.arn
      }
    ] }
  )
}