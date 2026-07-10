import json
import urllib.request
import urllib.error
import os
import google.auth.transport.requests
from google.oauth2 import service_account
import requests # Used by google.auth.transport.requests

def lambda_handler(event, context):
    print("Received event from EventBridge:", json.dumps(event))
    
    target_audience = os.environ.get('GCP_FUNCTION_URL')
    if not target_audience:
        raise ValueError("GCP_FUNCTION_URL environment variable is missing")
    
    key_path = os.path.join(os.path.dirname(__file__), 'lambda_invoker_sa.json')
    if not os.path.exists(key_path):
        raise FileNotFoundError(f"Service account key not found at {key_path}")

    try:
        # Load the service account credentials from the zipped file
        creds = service_account.IDTokenCredentials.from_service_account_file(
            key_path, target_audience=target_audience)
        
        # Refresh the credentials to get the identity token
        auth_req = google.auth.transport.requests.Request()
        creds.refresh(auth_req)
        token = creds.token
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'User-Agent': 'AWS-Lambda-Audit-Forwarder/1.0'
        }
        
        payload = json.dumps(event).encode('utf-8')
        req = urllib.request.Request(target_audience, data=payload, headers=headers, method='POST')
        
        with urllib.request.urlopen(req) as response:
            response_body = response.read().decode('utf-8')
            print(f"Success: {response_body}")
            return {
                'statusCode': response.status,
                'body': response_body
            }
            
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"HTTPError {e.code} calling Cloud Function: {error_body}")
        raise
    except Exception as e:
        print(f"Error calling Cloud Function: {e}")
        raise
