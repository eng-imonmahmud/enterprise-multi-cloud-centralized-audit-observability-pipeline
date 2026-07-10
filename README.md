<div align="center">
  <h1>🌐 Enterprise Multi-Cloud Centralized Audit & Observability Pipeline</h1>
  <p><i>A production-grade, highly secure, serverless pipeline bridging AWS and Google Cloud Platform for centralized audit logging and observability.</i></p>
  
  [![Status](https://img.shields.io/badge/status-completed-blue.svg)](#)
  [![License](https://img.shields.io/badge/license-MIT-blue.svg)](#)
  [![Platform](https://img.shields.io/badge/Platform-AWS%20%7C%20GCP-orange)](#)
  [![Language](https://img.shields.io/badge/Language-Python%20%7C%20PowerShell-blue)](#)
  
  <p><b>Last Updated:</b> 2026-07-11</p>
</div>

---

## 📑 Table of Contents

- [Executive Summary](#-executive-summary)
- [Business Use Case](#-business-use-case)
- [Architecture Overview](#-architecture-overview)
- [Architecture Diagram](#-architecture-diagram)
- [High-Level Data Flow](#-high-level-data-flow)
- [End-to-End Workflow](#-end-to-end-workflow)
- [Technology Stack](#-technology-stack)
- [Repository Structure](#-repository-structure)
- [Security Architecture](#-security-architecture)
- [Authentication Flow](#-authentication-flow)
- [AWS Components](#-aws-components)
- [Google Cloud Components](#-google-cloud-components)
- [Deployment Process](#-deployment-process)
- [End-to-End Testing Results](#-end-to-end-testing-results)
- [Validation Summary](#-validation-summary)
- [Cloud Logging Example](#-cloud-logging-example)
- [Cloud Storage Archive Example](#-cloud-storage-archive-example)
- [Project Highlights](#-project-highlights)
- [Cost Optimization](#-cost-optimization)
- [Cleanup Strategy](#-cleanup-strategy)
- [Troubleshooting](#-troubleshooting)
- [Lessons Learned](#-lessons-learned)
- [Future Improvements](#-future-improvements)
- [References](#-references)
- [License](#-license)
- [Author](#-author)
- [Screenshot Gallery](#-screenshot-gallery)

---

## 🚀 Executive Summary

> **Project Status:** This project is officially **closed** and **completed**. The production lifecycle has concluded, and all resources have been verified and documented.

The **Enterprise Multi-Cloud Centralized Audit & Observability Pipeline** is a resilient, serverless architectural solution designed to seamlessly bridge telemetry and audit logs between Amazon Web Services (AWS) and Google Cloud Platform (GCP). It leverages AWS EventBridge and AWS Lambda to collect and forward telemetry data, which is securely transmitted via authenticated HTTPS requests to a Google Cloud Function (Gen 2). The GCP environment then centrally processes, structure-logs, and archives the telemetry into Cloud Storage for long-term retention and compliance. 

Designed for enterprise-grade scalability, this pipeline ensures zero unauthenticated access, deep observability, and completely automated cross-platform infrastructure provisioning.

## 💼 Business Use Case

In modern enterprise environments, organizations often employ multi-cloud strategies to mitigate vendor lock-in and leverage best-of-breed services. However, this creates isolated silos for security logs, audit trails, and observability data. 

**Challenges Solved:**
- **Siloed Telemetry:** Centralizes cross-cloud audit logs into a single GCP project for SIEM integration.
- **Compliance & Retention:** Automatically archives immutable logs into GCP Cloud Storage to satisfy GDPR, HIPAA, and PCI-DSS compliance regulations.
- **Security Posture:** Replaces static, long-lived credentials with short-lived, dynamically assumed IAM identity tokens for cross-cloud authentication.
- **Operational Overhead:** Fully automates the deployment and testing lifecycle using idempotent Infrastructure as Code (IaC) principles.

## 🏗 Architecture Overview

The architecture is built completely on serverless, managed components to guarantee high availability and scale-to-zero capabilities.

### 📊 Architecture Diagram

```mermaid
graph TD
    subgraph AWS [Amazon Web Services eu-central-1]
        EB[EventBridge Schedule] -->|Triggers| L[AWS Lambda Log Forwarder]
        L -->|Assumes Role| IAM[AWS IAM Role]
    end

    subgraph Auth [Cross-Cloud Identity]
        L -->|Generates short-lived JWT/OIDC| GCP_SA[GCP Service Account Auth]
    end

    subgraph GCP [Google Cloud Platform europe-west3]
        GCP_SA -->|Authenticated HTTPS| CF[Cloud Function Gen2]
        CF -->|Structured Logs| CL[Cloud Logging]
        CF -->|Cold Archive JSON| CS[Cloud Storage Bucket]
    end
```

## 🌊 High-Level Data Flow

1. **Trigger:** Amazon EventBridge triggers the AWS Lambda forwarder on a defined schedule.
2. **Collection:** AWS Lambda collects internal audit metrics and telemetry.
3. **Authentication:** AWS Lambda uses a local temporary GCP Service Account mapping to generate an authorized OIDC bearer token.
4. **Transmission:** The payload is transmitted securely over TLS to the GCP Cloud Function via a REST `POST` request.
5. **Ingestion:** The GCP Cloud Function parses the JSON, structures it into a standard schema, and injects a UUID trace ID.
6. **Observability:** The payload is immediately logged to Google Cloud Logging for real-time dashboards and alerting.
7. **Archival:** The native JSON payload is written to Google Cloud Storage under a date-partitioned prefix (`YYYY/MM/DD`).

## 🔄 End-to-End Workflow

1. Automated setup of all GCP resources (Service Accounts, IAM policies, Storage Buckets, APIs, Cloud Functions).
2. Dynamic fetching of the GCP Function HTTPS trigger URL.
3. Automated provisioning of AWS resources (IAM Roles, Lambda packaging with Linux binaries, EventBridge Rules).
4. Continuous automated invocation between AWS and GCP.
5. Seamless lifecycle teardown scripts to prevent resource leakage.

## 🛠 Technology Stack

### Google Cloud Platform (GCP)
- **Cloud Functions (Gen 2):** Serverless compute for receiving HTTPS POST requests.
- **Cloud Storage:** Secure, highly durable object storage for audit log archival.
- **Cloud Logging (Operations Suite):** Structured logging for real-time observability.
- **Artifact Registry & Cloud Build:** Containerizes the Gen 2 Cloud Function.
- **IAM:** Strict least-privilege service account bindings.

### Amazon Web Services (AWS)
- **AWS Lambda:** Python-based serverless compute running on Amazon Linux.
- **Amazon EventBridge:** Serverless event bus and scheduler.
- **AWS IAM:** Role-based access control.

### Tools & Languages
- **Python 3.10:** Application logic for both AWS Lambda and GCP Cloud Functions.
- **PowerShell 7+:** End-to-end automation orchestration.
- **Google Cloud SDK (`gcloud`):** CLI management for GCP.
- **AWS CLI (`aws`):** CLI management for AWS.

## 📂 Repository Structure

```text
enterprise-multi-cloud-centralized-audit-observability-pipeline/
├── .gitignore
├── README.md
├── architecture/
├── aws-source/
│   ├── lambda_function.py
│   └── requirements.txt
├── cleanup-scripts/
│   └── destroy.ps1
├── configuration/
│   └── settings.ps1
├── deployment-scripts/
│   └── deploy.ps1
├── gcp-source/
│   ├── main.py
│   └── requirements.txt
├── screenshots/
└── test-scripts/
    └── test-e2e.ps1
```

## 🔒 Security Architecture

- **Zero Unauthenticated Access:** The GCP Cloud Function explicitly disables unauthenticated invocations (`--no-allow-unauthenticated`).
- **Least Privilege IAM:** 
  - The GCP Cloud Function runs under `audit-func-sa` with restricted permissions (Log Writer, Storage Object Admin).
  - The AWS Lambda is invoked using `audit-invoker-sa` exclusively holding the `roles/run.invoker` permission.
- **No Hardcoded Secrets in Code:** Credentials are dynamically injected via environment variables and temporary identity tokens.
- **Repository Hygiene:** A strict `.gitignore` safeguards against accidental credential exposure.
- **Data in Transit:** All traffic flows over TLS/HTTPS.

## 🔑 Authentication Flow

To successfully bridge the two clouds, the AWS Lambda acts as the client:
1. It reads an authorized GCP Service Account key configuration.
2. Utilizing the `google-auth` library, it negotiates an OpenID Connect (OIDC) identity token tailored specifically for the target Cloud Function URL.
3. It appends the `Authorization: Bearer <TOKEN>` header to the POST request.

## ☁ AWS Components

- **Lambda Function (`multi-cloud-log-forwarder`):** Built with Python 3.10. Relies on `requests` and `google-auth`. Uses `manylinux2014_x86_64` wheels for cross-platform C-extension compatibility (`cryptography`).
- **EventBridge Rule (`multi-cloud-audit-schedule`):** Configured on a 5-minute rate schedule.
- **IAM Role (`multi-cloud-lambda-role`):** Grants `AWSLambdaBasicExecutionRole` allowing CloudWatch metric generation.

## ☁ Google Cloud Components

- **Cloud Function (`multi-cloud-audit-api`):** A Gen 2 Cloud Function (powered by Cloud Run). Maps the `ARCHIVE_BUCKET` environment variable.
- **Cloud Storage (`imons-projects-audit-archive-4821`):** Stores logs in the `audit_logs/YYYY/MM/DD/` taxonomy.
- **Service Accounts:**
  - `audit-func-sa`: Bound to the function.
  - `audit-invoker-sa`: Bound to the AWS Lambda logic.

## 🚀 Deployment Process

The entire architecture is deployed autonomously using a single PowerShell script.

```powershell
.\deployment-scripts\deploy.ps1
```

**Actions Performed:**
- Synchronizes local configuration.
- Activates GCP credentials and enables all required APIs.
- Provisions GCP Cloud Storage and Service Accounts.
- Deploys the GCP Cloud Function.
- Assigns IAM bindings for cross-platform invocation.
- Generates a temporary JSON key for AWS identity context.
- Cross-compiles the Python dependencies for the Amazon Linux Lambda environment.
- Zips and provisions the AWS Lambda and IAM roles.
- Maps Amazon EventBridge to trigger the Lambda.
- Immediately sanitizes local temporary credentials to prevent secret leakage.

## 🧪 End-to-End Testing Results

The `test-e2e.ps1` script performs programmatic validation:

```powershell
.\test-scripts\test-e2e.ps1
```

**Output:**
```
Starting End-to-End Test for Multi-Cloud Centralized Audit Pipeline
Invoking AWS Lambda function manually...
Lambda Response: {"statusCode": 200, "body": "{\"event_id\":\"ed9826db-cab1-407d-8cfe-81180b974b9e\",\"status\":\"success\"}\n"}
Waiting 15 seconds for logs and storage to sync...
Checking GCP Cloud Storage bucket for archived logs...
Success! Found logs in GCP Storage Bucket: gs://imons-projects-audit-archive-4821/audit_logs/**
Checking GCP Cloud Logging for structured audit events...
Success! Found structured logs in GCP Cloud Logging.
End-to-End Test Completed successfully.
```

## ✅ Validation Summary

- [x] AWS EventBridge triggers Lambda on schedule.
- [x] AWS Lambda dynamically negotiates GCP OIDC Bearer tokens.
- [x] GCP Cloud Function receives and processes the payload natively.
- [x] GCP Cloud Logging records the telemetry instantly.
- [x] GCP Cloud Storage archives the exact payload successfully.

## 📝 Cloud Logging Example

Structured JSON entry captured in Google Cloud Logging:
```json
{
  "insertId": "64d008e0000301a24838b0cd",
  "jsonPayload": {
    "event_id": "405653e0-f3b7-4434-ae65-d5d14dcf499c",
    "payload": {
      "message": "Autonomous Audit Event"
    },
    "source": "aws-eventbridge",
    "timestamp": "2026-07-10T19:53:57.123456Z"
  },
  "logName": "projects/imons-projects/logs/audit-api-log",
  "severity": "INFO"
}
```

## 📦 Cloud Storage Archive Example

Native payload successfully written to `gs://imons-projects-audit-archive-4821/audit_logs/2026/07/10/audit-405653e0-f3b7-4434-ae65-d5d14dcf499c.json`:
```json
{
  "event_id": "405653e0-f3b7-4434-ae65-d5d14dcf499c",
  "timestamp": "2026-07-10T19:53:57.123456Z",
  "source": "aws-eventbridge",
  "payload": {
    "message": "Autonomous Audit Event"
  }
}
```

## ⭐ Project Highlights

- **Platform Engineering:** Fully automated infrastructure lifecycle utilizing idempotent scripts.
- **DevSecOps Integration:** Security-first implementation ensuring absolute zero unauthenticated access across cloud perimeters.
- **Cross-Cloud Identity:** Mastery over GCP IAM OIDC token negotiation directly from inside AWS Lambda.
- **Python CI/CD:** Dynamic cross-compilation of Python C-extension wheels (`manylinux`) on a Windows environment for Amazon Linux consumption.

## 💰 Cost Optimization

- Both AWS Lambda and GCP Cloud Functions utilize Serverless models resulting in $0 charges when idle.
- Cloud Storage acts as cold storage minimizing long-term data retention costs compared to active SIEM ingestion.

## 🧹 Cleanup Strategy

To prevent idle resource leakage, the infrastructure can be safely torn down using:

```powershell
.\cleanup-scripts\destroy.ps1
```

This ensures all IAM roles, event rules, Lambdas, Cloud Functions, and Storage buckets are fully purged.

## 🔧 Troubleshooting

- **ModuleNotFoundError in AWS Lambda:** Ensure dependencies are packaged with `--platform manylinux2014_x86_64` and `--only-binary=:all:` to avoid Windows C-extensions being uploaded to Amazon Linux.
- **GCP 403 Forbidden on Cloud Function:** Ensure the AWS Lambda possesses the correct Bearer Token mapped to a Service Account possessing the `roles/run.invoker` role.

## 🧠 Lessons Learned

- Integrating multi-cloud IAM involves highly specific OIDC identity translation.
- PowerShell robustly handles Cloud API interactions when leveraging proper exception handling (`$ErrorActionPreference`).
- Cross-platform dependency packaging (`pip` wheel compatibility) is critical for serverless deployments.

## 🔭 Future Improvements

- Migrate PowerShell deployment scripts to HashiCorp Terraform for stateful IaC management.
- Implement AWS Secrets Manager / GCP Secret Manager for temporary SA key distribution to eliminate local filesystem touches.
- Integrate Datadog or Splunk forwarders for extended SIEM visibility.

## 📚 References

- [Google Cloud Functions Authentication](https://cloud.google.com/functions/docs/securing/authenticating)
- [AWS Lambda Deployment Packages](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html)
- [Amazon EventBridge Overview](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Imon Mahmud**  
*IT SPECIALIST | CLOUD INFRASTRUCTURE & AI AUTOMATION ENGINEER*

---

## 📸 Screenshot Gallery
<br>

![Screenshot](./screenshots/screencapture-console-cloud-google-run-detail-europe-west3-multi-cloud-audit-api-observability-logs-2026-07-11-02_03_58.png)
![Screenshot](./screenshots/screencapture-console-cloud-google-run-detail-europe-west3-multi-cloud-audit-api-observability-metrics-2026-07-11-02_03_46.png)
![Screenshot](./screenshots/screencapture-console-cloud-google-run-detail-europe-west3-multi-cloud-audit-api-revisions-2026-07-11-02_04_11.png)
![Screenshot](./screenshots/screencapture-console-cloud-google-run-detail-europe-west3-multi-cloud-audit-api-security-2026-07-11-02_04_47.png)
![Screenshot](./screenshots/screencapture-console-cloud-google-run-detail-europe-west3-multi-cloud-audit-api-source-2026-07-11-02_04_33.png)
![Screenshot](./screenshots/screencapture-console-cloud-google-storage-browser-imons-projects-audit-archive-4821-audit-logs-2026-07-10-2026-07-11-02_06_39.png)
![Screenshot](./screenshots/screencapture-console-cloud-google-storage-browser-imons-projects-audit-archive-4821-tab-objects-2026-07-11-02_06_20.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-cloudwatch-home-2026-07-11-02_02_40.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-cloudwatch-home-2026-07-11-02_03_09.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-events-home-2026-07-11-02_01_09.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-events-home-2026-07-11-02_01_26.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-events-home-2026-07-11-02_01_46.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-lambda-home-2026-07-11-01_59_01.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-lambda-home-2026-07-11-01_59_25.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-lambda-home-2026-07-11-01_59_51.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-lambda-home-2026-07-11-02_00_04.png)
![Screenshot](./screenshots/screencapture-eu-central-1-console-aws-amazon-lambda-home-2026-07-11-02_00_13.png)
