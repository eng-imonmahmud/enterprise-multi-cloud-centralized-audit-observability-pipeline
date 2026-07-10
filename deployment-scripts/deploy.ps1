$env:CLOUDSDK_PYTHON = (Get-Command python).Path
$env:CLOUDSDK_PYTHON_SITEPACKAGES = '1'
$env:PATH += ';C:\google-cloud-sdk\bin'

$ErrorActionPreference = "Continue"

# 1. Load Settings
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

Write-Host "Starting deployment of Multi-Cloud Centralized Audit & Observability Pipeline..." -ForegroundColor Green

# 2. Check and Configure GCP Authentication
if (-not $env:GOOGLE_APPLICATION_CREDENTIALS) {
    $fallbackJson = "E:\VS Code Project\enterprise-multi-cloud-centralized-audit-observability-pipeline\imons-projects-14ba0d56ccce.json"
    if (Test-Path $fallbackJson) {
        Write-Host "Using fallback local service account JSON for GCP authentication." -ForegroundColor Yellow
        $env:GOOGLE_APPLICATION_CREDENTIALS = $fallbackJson
        gcloud auth activate-service-account --key-file=$fallbackJson --project=$GCPProjectID | Out-Null
    } else {
        Write-Host "No GOOGLE_APPLICATION_CREDENTIALS and no fallback JSON found. Assuming already authenticated." -ForegroundColor Yellow
    }
}
gcloud config set project $GCPProjectID | Out-Null

# 3. Enable GCP APIs
Write-Host "Enabling required GCP APIs..." -ForegroundColor Cyan
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com logging.googleapis.com storage.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

# 4. Create GCP Bucket
Write-Host "Creating Cloud Storage bucket $GCPBucketName..." -ForegroundColor Cyan
$bucketExists = gcloud storage ls gs://$GCPBucketName 2>&1
if ($LASTEXITCODE -ne 0) {
    gcloud storage buckets create gs://$GCPBucketName --location=$GCBRegion
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create bucket"; exit 1 }
} else {
    Write-Host "Bucket already exists." -ForegroundColor Yellow
}

# 5. Create GCP Service Accounts
Write-Host "Setting up GCP IAM Service Accounts..." -ForegroundColor Cyan
$funcSaEmail = "$GCPServiceAccount@$GCPProjectID.iam.gserviceaccount.com"
$invokerSaEmail = "$GCPInvokerAccount@$GCPProjectID.iam.gserviceaccount.com"

# Create Function SA
gcloud iam service-accounts describe $funcSaEmail 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    gcloud iam service-accounts create $GCPServiceAccount --display-name="Audit Cloud Function Identity"
}
# Grant permissions to Function SA
gcloud projects add-iam-policy-binding $GCPProjectID --member="serviceAccount:$funcSaEmail" --role="roles/storage.objectAdmin" | Out-Null
gcloud projects add-iam-policy-binding $GCPProjectID --member="serviceAccount:$funcSaEmail" --role="roles/logging.logWriter" | Out-Null

# Create Invoker SA
gcloud iam service-accounts describe $invokerSaEmail 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    gcloud iam service-accounts create $GCPInvokerAccount --display-name="Audit Lambda Invoker Identity"
}

# 6. Deploy GCP Cloud Function
Write-Host "Deploying GCP Cloud Function Gen2..." -ForegroundColor Cyan
gcloud functions deploy $GCPFunctionName `
    --gen2 `
    --runtime=python310 `
    --region=$GCBRegion `
    --source=.\gcp-source `
    --entry-point=audit_handler `
    --trigger-http `
    --service-account=$funcSaEmail `
    --set-env-vars="ARCHIVE_BUCKET=$GCPBucketName" `
    --no-allow-unauthenticated

if ($LASTEXITCODE -ne 0) { Write-Error "Failed to deploy Cloud Function"; exit 1 }

# Get the Cloud Function URL
$functionUrl = gcloud functions describe $GCPFunctionName --gen2 --region=$GCBRegion --format="value(serviceConfig.uri)"
Write-Host "Cloud Function URL: $functionUrl" -ForegroundColor Green

# Grant Invoker SA permission to invoke the function
gcloud functions add-iam-policy-binding $GCPFunctionName `
    --gen2 `
    --region=$GCBRegion `
    --member="serviceAccount:$invokerSaEmail" `
    --role="roles/cloudfunctions.invoker" | Out-Null

gcloud run services add-iam-policy-binding $GCPFunctionName `
    --region=$GCBRegion `
    --member="serviceAccount:$invokerSaEmail" `
    --role="roles/run.invoker" | Out-Null

# 7. Generate Temporary SA Key for AWS Lambda
Write-Host "Generating temporary Service Account Key for AWS Lambda..." -ForegroundColor Cyan
$keyPath = ".\aws-source\lambda_invoker_sa.json"
if (Test-Path $keyPath) { Remove-Item $keyPath -Force }
gcloud iam service-accounts keys create $keyPath --iam-account=$invokerSaEmail

# 8. Package AWS Lambda
Write-Host "Packaging AWS Lambda..." -ForegroundColor Cyan
$lambdaPackageDir = ".\lambda_package"
if (Test-Path $lambdaPackageDir) { Remove-Item -Recurse -Force $lambdaPackageDir }
New-Item -ItemType Directory -Path $lambdaPackageDir | Out-Null

# Install dependencies
python -m pip install --platform manylinux2014_x86_64 --target $lambdaPackageDir --implementation cp --python-version 3.10 --only-binary=:all: --upgrade -r .\aws-source\requirements.txt
Copy-Item .\aws-source\lambda_function.py -Destination $lambdaPackageDir
Copy-Item $keyPath -Destination $lambdaPackageDir

# Create zip
$zipPath = ".\deployment.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path "$lambdaPackageDir\*" -DestinationPath $zipPath

# 9. Deploy AWS Resources
Write-Host "Deploying AWS Resources..." -ForegroundColor Cyan

# Create IAM Role
$assumeRolePolicy = '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Principal": { "Service": "lambda.amazonaws.com" }, "Action": "sts:AssumeRole" } ] }'
$policyFile = ".\assume_role_policy.json"
Set-Content $policyFile $assumeRolePolicy

aws iam get-role --role-name $AWSRoleName 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    aws iam create-role --role-name $AWSRoleName --assume-role-policy-document file://$policyFile | Out-Null
    aws iam attach-role-policy --role-name $AWSRoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" | Out-Null
    Write-Host "Waiting 15 seconds for IAM Role propagation..."
    Start-Sleep -Seconds 15
}

$roleArn = (aws iam get-role --role-name $AWSRoleName --query 'Role.Arn' --output text)

# Deploy Lambda
aws lambda get-function --function-name $AWSLambdaName --region $AWSRegion 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    aws lambda create-function `
        --function-name $AWSLambdaName `
        --region $AWSRegion `
        --runtime python3.10 `
        --role $roleArn `
        --handler lambda_function.lambda_handler `
        --zip-file fileb://$zipPath `
        --timeout 30 `
        --environment "Variables={GCP_FUNCTION_URL=$functionUrl}" | Out-Null
} else {
    aws lambda update-function-code `
        --function-name $AWSLambdaName `
        --region $AWSRegion `
        --zip-file fileb://$zipPath | Out-Null
    
    # Wait until update is successful
    aws lambda wait function-updated --function-name $AWSLambdaName --region $AWSRegion
    
    aws lambda update-function-configuration `
        --function-name $AWSLambdaName `
        --region $AWSRegion `
        --timeout 30 `
        --environment "Variables={GCP_FUNCTION_URL=$functionUrl}" | Out-Null
}

$lambdaArn = (aws lambda get-function --function-name $AWSLambdaName --region $AWSRegion --query 'Configuration.FunctionArn' --output text)

# Configure EventBridge
Write-Host "Configuring AWS EventBridge..." -ForegroundColor Cyan
aws events put-rule `
    --name $AWSEventRuleName `
    --schedule-expression "rate(5 minutes)" `
    --state ENABLED `
    --region $AWSRegion | Out-Null

# Add permission for EventBridge to invoke Lambda
$policy = aws lambda get-policy --function-name $AWSLambdaName --region $AWSRegion 2>&1
if ($policy -notmatch "EventBridgeInvoke") {
    aws lambda add-permission `
        --function-name $AWSLambdaName `
        --region $AWSRegion `
        --statement-id "EventBridgeInvoke" `
        --action "lambda:InvokeFunction" `
        --principal "events.amazonaws.com" `
        --source-arn (aws events describe-rule --name $AWSEventRuleName --region $AWSRegion --query 'Arn' --output text) | Out-Null
}

# Add Target
aws events put-targets `
    --rule $AWSEventRuleName `
    --region $AWSRegion `
    --targets "Id=1,Arn=$lambdaArn" | Out-Null

# 10. Cleanup Local Sensitive Artifacts immediately
Write-Host "Cleaning up local temporary credentials..." -ForegroundColor Yellow
if (Test-Path $keyPath) { Remove-Item $keyPath -Force }
if (Test-Path $lambdaPackageDir) { Remove-Item -Recurse -Force $lambdaPackageDir }
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
if (Test-Path $policyFile) { Remove-Item -Force $policyFile }

Write-Host "Deployment completed successfully!" -ForegroundColor Green
