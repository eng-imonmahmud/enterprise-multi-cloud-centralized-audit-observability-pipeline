$ProjectConfig = @{
    GCPProjectID         = "imons-projects"
    GCBRegion            = "europe-west3" # Defaulting to Frankfurt for GCP to match AWS eu-central-1
    GCPBucketName        = "imons-projects-audit-archive-4821"
    GCPServiceAccount    = "audit-func-sa"
    GCPInvokerAccount    = "audit-invoker-sa"
    GCPFunctionName      = "multi-cloud-audit-api"
    AWSRegion            = "eu-central-1"
    AWSLambdaName        = "multi-cloud-log-forwarder"
    AWSRoleName          = "multi-cloud-lambda-role"
    AWSEventRuleName     = "multi-cloud-audit-schedule"
}
