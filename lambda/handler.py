"""AWS glue for the gauze redaction endpoint.

Reads an object through the supporting S3 access point, detects PHI with
    Comprehend Medical, and returns the de-identified text over the Function URL.
"""
 
import os
import urllib.parse
 
import boto3
from botocore.exceptions import ClientError
 
from redaction import normalize_comprehend, redact
 
s3 = boto3.client("s3")
comprehend = boto3.client("comprehendmedical")
 
# The read target is fixed at deploy time. Callers supply only an object key,
# never a bucket, so this function cannot be pointed at other data by request.
SUPPORTING_AP = os.environ["SUPPORTING_AP_ARN"]
TRANSFORM_MODE = os.environ.get("TRANSFORM_MODE", "passthrough").strip().lower()
 
# Comprehend Medical's synchronous DetectPHI limit.
MAX_DETECT_BYTES = 20_000
 
# Entities below this score are still redacted; the threshold only decides
# what gets logged for later tuning.
LOW_CONFIDENCE = 0.5
 
 
def _text(status: int, body: str) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "text/plain"},
        "body": body,
    }
 
 
def lambda_handler(event, context):
    key = urllib.parse.unquote(event.get("rawPath", "/").lstrip("/"))
    if not key:
        return _text(400, "Missing object key.")
 
    try:
        obj = s3.get_object(Bucket=SUPPORTING_AP, Key=key)
    except ClientError as exc:
        code = exc.response["Error"]["Code"]
        if code in ("NoSuchKey", "404", "AccessDenied"):
            return _text(404, "Not found.")
        print(f"s3 get_object failed: {code}")
        return _text(500, "Internal error.")
 
    body = obj["Body"].read().decode("utf-8")
 
    if TRANSFORM_MODE != "redact":
        return _text(200, body)
 
    if not body.strip():
        return _text(200, body)
 
    if len(body.encode("utf-8")) > MAX_DETECT_BYTES:
        # Refusing beats redacting the first 20 KB and returning the rest
        # untouched, which would leak everything past the cut.
        # TODO: chunk across calls, handling entities that straddle boundaries.
        return _text(413, "Document exceeds the detection size limit.")
 
    try:
        entities = comprehend.detect_phi(Text=body)["Entities"]
    except ClientError as exc:
        print(f"detect_phi failed: {exc.response['Error']['Code']}")
        return _text(500, "Internal error.")
 
    # No confidence filter: a missed identifier is a compliance incident, an
    # over-redaction is noise. Low scores are logged, not dropped.
    for entity in entities:
        if entity["Score"] < LOW_CONFIDENCE:
            print(
                f"low-confidence redaction: {entity['Type']} "
                f"score={entity['Score']:.2f}"
            )
 
    return _text(200, redact(body, normalize_comprehend(entities)))