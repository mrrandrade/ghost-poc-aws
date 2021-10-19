
resource "aws_s3_bucket" "ghost_logs" {
  bucket = "ghost-poc-client-logging-bucket"
  acl    = "private"

  tags = merge(
      local.tags
  )
}

# Watch out for this gotcha!
# Your bucket policy has to allow AWS accounts to be able to write on it for logging.
# Its not sufficient to clear the Service host delivery.logs.amazonaws.com, you're 
# also required to clear the account that owns the ELBs.

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "ghost_logs_bucket_policy" {
  bucket = aws_s3_bucket.ghost_logs.id

  policy = jsonencode({
    "Version": "2012-10-17"
    "Id": "ghost_logs_bucket_policy"
    "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_elb_service_account.main.arn}"
      },
      "Action": "s3:PutObject",
      "Resource": [ "${aws_s3_bucket.ghost_logs.arn}/ghost/alb/*", "${aws_s3_bucket.ghost_logs.arn}/ghost/cloudfront/*" ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": [ "${aws_s3_bucket.ghost_logs.arn}/ghost/alb/*", "${aws_s3_bucket.ghost_logs.arn}/ghost/cloudfront/*" ]
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "${aws_s3_bucket.ghost_logs.arn}"
    }
  ]
  })
}