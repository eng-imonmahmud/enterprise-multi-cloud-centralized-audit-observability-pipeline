import functions_framework
import json
import os
import uuid
import datetime
from google.cloud import storage
import google.cloud.logging
from flask import jsonify

# Initialize logging client once (cold start optimization)
logging_client = google.cloud.logging.Client()
logger = logging_client.logger("audit-api-log")

# Initialize storage client once
storage_client = storage.Client()
bucket_name = os.environ.get('ARCHIVE_BUCKET')
bucket = storage_client.bucket(bucket_name) if bucket_name else None

@functions_framework.http
def audit_handler(request):
    """HTTP Cloud Function to receive audit logs."""
    try:
        request_json = request.get_json(silent=True)
        if not request_json:
            return jsonify({"error": "Invalid JSON or missing body"}), 400

        # Create structured log
        audit_event = {
            "event_id": str(uuid.uuid4()),
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "source": "aws-eventbridge",
            "payload": request_json
        }

        # 1. Write to Google Cloud Logging
        logger.log_struct(
            audit_event,
            severity="INFO"
        )

        # 2. Archive to Google Cloud Storage
        if bucket:
            file_name = f"audit_logs/{datetime.datetime.utcnow().strftime('%Y/%m/%d')}/audit-{audit_event['event_id']}.json"
            blob = bucket.blob(file_name)
            blob.upload_from_string(
                json.dumps(audit_event, indent=2),
                content_type='application/json'
            )
            print(f"Successfully archived audit event to gs://{bucket_name}/{file_name}")
        else:
            print("Warning: ARCHIVE_BUCKET environment variable not set, skipping GCS archiving.")

        return jsonify({"status": "success", "event_id": audit_event["event_id"]}), 200

    except Exception as e:
        print(f"Error processing audit request: {e}")
        return jsonify({"error": "Internal Server Error"}), 500
