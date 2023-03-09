terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_iam_role" "Lambda-Rekognition-Role" {
  name        = "Lambda-Rekognition-Role"
  description = "Allows AWS to call Rekognize, s3, and DyanmoDB on your behalf."
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonRekognitionFullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_s3_bucket" "vehicle-images" {
  bucket = "vehicle-pictures"
}

resource "aws_dynamodb_table" "vehicle-predictions" {
  name           = "RekognizeVehiclePredictions"
  hash_key       = "Key"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "Key"
    type = "S"
  }
}


resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prediction-vehicle-images.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.vehicle-images.arn
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "../python/lambda_function.py"
  output_path = "../python/lambda_function.zip"
}

resource "aws_lambda_function" "prediction-vehicle-images" {
  function_name    = "predict-vehicle-images"
  role             = aws_iam_role.Lambda-Rekognition-Role.arn
  description      = "Predicts the presence of a vehicle in an image using Rekognition"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.lambda_function.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_function.output_path)
  environment {
    variables = {
      TABLE_NAME            = aws_dynamodb_table.vehicle-predictions.name
      PROBABILITY_THRESHOLD = var.probability_threshold
      ACCEPTED_LABELS       = var.accepted_labels
      PASSWORD              = var.password
    }
  }
}


resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.vehicle-images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.prediction-vehicle-images.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
