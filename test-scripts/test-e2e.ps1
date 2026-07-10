$env:CLOUDSDK_PYTHON = (Get-Command python).Path
$env:CLOUDSDK_PYTHON_SITEPACKAGES = '1'
$env:PATH += ';C:\google-cloud-sdk\bin'

$ErrorActionPreference = "Continue"

. .\configuration\settings.ps1
$GCPProjectID = $ProjectConfig.GCPProjectID
$GCBRegion = $ProjectConfig.GCBRegion
$GCPBucketName = $ProjectConfig.GCPBucketName
$GCPServiceAccount = $ProjectConfig.GCPServiceAccount
$GCPInvokerAccount = $ProjectConfig.GCPInvokerAccount
$GCPFunctionName = $ProjectConfig.GCPFunctionName
$AWSRegion = $ProjectConfig.AWSRegion
$AWSLambdaName = $ProjectConfig.AWSLambdaName
$AWSRoleName = $ProjectConfig.AWSRoleName
$AWSEventRuleName = $ProjectConfig.AWSEventRuleName

Write-Host "Starting End-to-End Test for Multi-Cloud Centralized Audit Pipeline" -ForegroundColor Cyan

# 1. Invoke Lambda manually
Write-Host "Invoking AWS Lambda function manually..." -ForegroundColor Yellow
$payloadFile = ".\test_payload.json"
'{"message": "Manual e2e test event"}' | Out-File -FilePath $payloadFile -Encoding utf8
$responseFile = ".\lambda_response.json"
aws lambda invoke --function-name $AWSLambdaName --region $AWSRegion --payload fileb://$payloadFile --cli-binary-format raw-in-base64-out $responseFile | Out-Null
$lambdaResponse = Get-Content $responseFile
Write-Host "Lambda Response: $lambdaResponse" -ForegroundColor Green
Remove-Item $responseFile -Force
Remove-Item $payloadFile -Force

Write-Host "Waiting 15 seconds for logs and storage to sync..."
Start-Sleep -Seconds 15

# 2. Check GCP Cloud Storage
Write-Host "Checking GCP Cloud Storage bucket for archived logs..." -ForegroundColor Yellow
$gsPath = "gs://$GCPBucketName/audit_logs/**"

$bucketContents = gcloud storage ls $gsPath 2>&1
if ($LASTEXITCODE -eq 0 -and $bucketContents.Length -gt 0) {
    Write-Host "Success! Found logs in GCP Storage Bucket: $gsPath" -ForegroundColor Green
    $bucketContents | Write-Host
} else {
    Write-Host "Warning: No logs found in GCP Storage Bucket yet or path does not exist." -ForegroundColor Red
    Write-Host $bucketContents
    exit 1
}

# 3. Check GCP Cloud Logging
Write-Host "Checking GCP Cloud Logging for structured audit events..." -ForegroundColor Yellow
$logs = gcloud logging read "logName=projects/$GCPProjectID/logs/audit-api-log" --limit=5 --format="json" 2>&1
if ($LASTEXITCODE -eq 0 -and $logs -ne "[]" -and $logs.Length -gt 10) {
    Write-Host "Success! Found structured logs in GCP Cloud Logging." -ForegroundColor Green
} else {
    Write-Host "Warning: Could not find structured logs in GCP." -ForegroundColor Red
    exit 1
}

Write-Host "End-to-End Test Completed successfully." -ForegroundColor Cyan
