# Where to store Ghost Token?

resource "aws_secretsmanager_secret" "ghost_token" {
  name = "ghost_token"
  
  tags = merge(
    local.tags
  )    
}

resource "aws_secretsmanager_secret_version" "ghost_token" {
  secret_id     = aws_secretsmanager_secret.ghost_token.id
  secret_string = var.ghost_token
}

resource "aws_iam_role" "ghost_lambda_role" {
  name = "ghost_lambda_role"

  assume_role_policy = <<EOF
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
EOF
  tags = merge(
    local.tags
  )  
}

resource "aws_iam_policy" "secrets_manager_ghost_token" {
  name        = "secrets_manager_ghost_token"
  path        = "/"
  description = "Access to Ghost token on Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
          "Effect": "Allow",
          "Action": [
              "secretsmanager:GetResourcePolicy",
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret",
              "secretsmanager:ListSecretVersionIds"
          ],
          "Resource": [
              "${aws_secretsmanager_secret.ghost_token.arn}"
          ]
      }
    ]
  })

  tags = merge(
    local.tags
  )  
}

resource "aws_iam_policy_attachment" "ghost_lambda_role" {
  name       = "ghost_lambda_role"
  roles      = [aws_iam_role.ghost_lambda_role.name]
  policy_arn = aws_iam_policy.secrets_manager_ghost_token.arn
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "./files/lambda/ghost_delete_posts_layer.zip"
  layer_name = "ghost_delete_posts_dependencies"

  compatible_runtimes = ["python3.8"]
}

resource "aws_lambda_function" "ghost_delete_posts" {
  filename      = "./files/lambda/ghost_delete_posts.zip"
  function_name = "ghost_delete_posts"
  role          = aws_iam_role.ghost_lambda_role.arn
  handler       = "ghost_delete_posts.lambda_handler"
  
  source_code_hash = filebase64sha256("./files/lambda/ghost_delete_posts.zip")
  layers = [aws_lambda_layer_version.lambda_layer.arn]

  runtime = "python3.8"

  environment {
    variables = {
      "GHOST_URL" = "http://${aws_lb.ghost_alb.dns_name}/ghost/api/canary/admin/db/"
    }
  }
  tags = merge(
    local.tags,
    {"name": "ghost_elb"}
  )  
}