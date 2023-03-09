# aws-vehicle-classification

This project utilizes aws services and python code to determine whether a image is valid or not. Valid images consist of clear images of vehicles at various angles, subcomponents of vehicles, and vehicle accessories (keys etc.). When an image is dropped in a s3 bucket, the image is fed into a lambda function that that makes a call to the rekognition api. The lambda function uses the rekognition response labels as well as a probability threshold to make a determination of if an image is valid or not. The appropriate results are logged to a DynamoDB table, and they are posted to a route provided for the API. The project utilizes terrafrom to implement IaC.

# Terraform

Appropriate terraform scripts can be found in the tf folder. The main logic resides in a script called main.tf. Here's a birds eye view of the resources that are created in the file :

- "aws_iam_role" "Lambda-Rekognition-Role"
  - This is a role that has the appropriate policies to execute. Policy permissions should be set to be more specific if moving from a POC
    environment to a production environment.
- "aws_s3_bucket" "vehicle-images"
  - s3 bucket to drop files into
- "aws_dynamodb_table" "vehicle-predictions"
  - dynamodb table where results are logged
- "aws_lambda_function" "prediction-vehicle-images"
  - terraform utilizes a zipfile python/lambda_function.zip (this zipfile is created on terrafrom apply using data "archive_file" "lambda_function" from python/lambda_function.py) to create the appropriate lambda function
- "aws_s3_bucket_notification" "bucket_notification"
  - Creates a trigger that occurs whenever a file is dropped in "aws_s3_bucket" "vehicle-images"

Two additional files were created. The first of those files is the terraform.tfvars file which defines three variables

- accepted_labels
  - These are the labels that I found that worked well on the data that was provided from test data.
- probability_threshold
  - This is the threshold of accepted probability. If rekognition returns a label that is in accepted_labels and the label's probability is greater than or equal to the probability threshold, then an image is classified as valid
- password
  - This is the password needed to get the bearer token for the API.

The third file needed is a file called variables.tf. This file contains the actual values of the variables defined in terrafrom.tfvars. You can change the accepted labels if you wanted to account for more labels. You can adjust the probability threshold if you wanted to make adjust for precision vs. recall based on buisness needs. Additionally, this contains a password, so I won't commit this directly to github, and I will provide this through some other means.

- accepted_labels
  - Labels are set to "car, vehicle, tire, bumper, license plate, gauge, text, wheel, accessories, electronics, keys". This is based on the test ran on data
- probability_threshold
  - Set to 90 (this is based on the test ran on data)
  - Set to provided password 

The state file can also be provided as needed.

# Python

The logic for the lambda function is constructed as a python script python/lambda_function.py. The entry point that triggers when an item is uploaded to the lambda can be seen in the function named `lambda_handler(event, context):`. The function receives an image when it is dropped in an s3 bucket and calls three different methods to perform the appropriate actions. The variables accepted_labels, probability_threshold, and password are read in as environment variables, and they are defined in variables.tf.

- `detect_labels(bucket, key)`
  - Method takes in a the bucket name and the filename as the variable key. A call is made to rekognition to determine whether an image is valid or not. Based on the probability_threshold and the accepted_labels the code makes a determination whether the image is valid or not. This returns a tuple `return (key, labels, prediction)` that is used to add a entry to vehicle-predictions table as
- `write_prediction_to_dynamo(key, labels, prediction)`
  - Takes in the key, labels, and predictions from detect labels and writes to DynamoDB table vehicle-predictions
- `post_to_api(key, prediction)`
  - Takes in the key, labels, and predictions from detect labels and make appropriate calls to get bearer token for API authentication, and makes a post API call to the appropriate method.


