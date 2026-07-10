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

Write-Host "Starting destruction of Multi-Cloud Centralized Audit Pipeline..." -ForegroundColor Red

# AWS Cleanup
Write-Host "Removing EventBridge Rule Target..." -ForegroundColor Yellow
aws events remove-targets --rule $AWSEventRuleName --ids "1" --region $AWSRegion | Out-Null

Write-Host "Deleting EventBridge Rule..." -ForegroundColor Yellow
aws events delete-rule --name $AWSEventRuleName --region $AWSRegion | Out-Null

Write-Host "Deleting Lambda Function..." -ForegroundColor Yellow
aws lambda delete-function --function-name $AWSLambdaName --region $AWSRegion | Out-Null

Write-Host "Deleting IAM Role..." -ForegroundColor Yellow
aws iam detach-role-policy --role-name $AWSRoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" | Out-Null
aws iam delete-role --role-name $AWSRoleName | Out-Null

Write-Host "AWS Cleanup Complete." -ForegroundColor Green

# GCP Cleanup
Write-Host "Deleting GCP Cloud Function..." -ForegroundColor Yellow
gcloud functions delete $GCPFunctionName --gen2 --region=$GCBRegion --quiet

Write-Host "Deleting GCP Service Accounts..." -ForegroundColor Yellow
$funcSaEmail = "$GCPServiceAccount@$GCPProjectID.iam.gserviceaccount.com"
$invokerSaEmail = "$GCPInvokerAccount@$GCPProjectID.iam.gserviceaccount.com"
gcloud iam service-accounts delete $funcSaEmail --quiet
gcloud iam service-accounts delete $invokerSaEmail --quiet

Write-Host "Deleting GCP Storage Bucket and contents..." -ForegroundColor Yellow
gcloud storage rm --recursive gs://$GCPBucketName/ --quiet

Write-Host "GCP Cleanup Complete." -ForegroundColor Green
Write-Host "All billable resources have been destroyed." -ForegroundColor Cyan
