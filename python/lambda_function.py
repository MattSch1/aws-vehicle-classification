import boto3
import json
import urllib.parse
import urllib3
import os


rekognition = boto3.client('rekognition')
http = urllib3.PoolManager()
prediction_threshold = float(os.environ['PROBABILITY_THRESHOLD'])
table_name = os.environ['TABLE_NAME']
accepted_labels = [x.strip().lower()
                   for x in os.environ['ACCEPTED_LABELS'].split(',')]
password = os.environ['PASSWORD']


def detect_labels(bucket, key):
    response = rekognition.detect_labels(
        Image={"S3Object": {"Bucket": bucket, "Name": key}})
    prediction = False
    labels = []

    for label_prediction in response['Labels']:
        name = label_prediction['Name'].lower()
        confidence = round(label_prediction['Confidence'], 2)
        if name in accepted_labels and confidence >= prediction_threshold:
            prediction = True
        labels.append({'Confidence': confidence, 'Name': name})
    return (key, labels, prediction)


def write_prediction_to_dynamo(key, labels, prediction):
    try:
        table = boto3.resource('dynamodb').Table(table_name)
        table.put_item(Item={'Key': key, 'LabelsJson': json.dumps(
            labels, indent=2), 'VehiclePrediction': prediction})
    except Exception as e:
        print(e)
        print("Error writing to DynamoDB table.")
        raise e


def post_to_api(key, prediction):
    try:
        bearer_token = get_bearer_token()
        int_prediction = 1 if prediction else 2
        response = post_rekognize_results(key, bearer_token, int_prediction)
        return response
    except Exception as e:
        print(e)
        print("Error posting to foo API.")
        raise e


def get_bearer_token():
    url = 'https://identity.foo.com/connect/token'
    data = {'grant_type': 'password',
            'scope': 'offline_access api permissions',
            'Username': 'username',
            'Password': password,
            'client_id': 'ro.client',
            'Client_secret': 'secret'}
    headers = {'Content-Type': 'application/x-www-form-urlencoded'}
    encoded_data = urllib.parse.urlencode(data)
    response = http.request('POST', url, body=encoded_data, headers=headers)
    print(
        f"Response code for getting bearer token is {response.status}")
    bearer_token = json.loads(response.data)['access_token']
    return bearer_token


def post_rekognize_results(filename, bearer_token, status):
    headers = {'Authorization': 'Bearer ' + bearer_token}
    params = {'filename': filename,
              'status': status}
    encoded_params = urllib.parse.urlencode(params)
    url = 'https://foobar?' + encoded_params
    response = http.request('POST', url, headers=headers)
    print(f"Response code for foo api post is {response.status}")
    data = json.loads(response.data)
    return data


def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
    try:
        key, labels, prediction = detect_labels(bucket, key)
        write_prediction_to_dynamo(key, labels, prediction)
        post_to_api(key, prediction)
        return {'statusCode': 200, 'body': json.dumps(f'{key} was processed successfully.')}
    except Exception as e:
        print(e)
        print(f"Error processing object {key} from bucket {bucket}.")
        raise e
