Step 1 — Create S3 Bucket for Reports
Step 2 — Create SNS Topic
Step 3 — Create IAM Role and inline policy for Lambda
Step 4 — Create the AWS Config Rule
Step 5 — Create the Lambda Function
Step 6 — Create EventBridge Rule for Weekly Schedule


{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "config:GetComplianceDetailsByConfigRule",
        "config:DescribeComplianceByConfigRule",
        "config:DescribeConfigRules"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::org-compliance-reports-[youraccountid]/*"
    },
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:[your-region]:[youraccountid]:compliance-report-notifications"
    }
  ]
}
```

Replace the bucket name, region, and account ID → **Next** → name it `compliance-lambda-inline` → **Create Policy**

---

## Step 4 — Create the AWS Config Rule

Go to **AWS Config Console → Rules → Add Rule**

- Rule type: **AWS managed rule**
- Search for `required-tags` → select it → Next
- Rule name: `required-tags-rule`
- Scope of changes: **All changes** (or specific resource types if you want to narrow it)

Scroll down to **Parameters** — this is where you define which tags are required:
```
Key: tag1Key     Value: Environment
Key: tag2Key     Value: Owner
Key: tag3Key     Value: CostCenter

## Step 5 - Create lambda functions
import boto3
import csv
import io
import os
from datetime import datetime, timezone

config_client = boto3.client('config')
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

BUCKET_NAME = os.environ['BUCKET_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
RULE_NAME = os.environ['RULE_NAME']

def lambda_handler(event, context):
    print("Starting compliance report generation")
    
    # Get compliance results
    results = get_compliance_results()
    
    # Generate CSV
    csv_content = generate_csv(results)
    
    # Upload to S3
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d_%H-%M-%S')
    s3_key = f'reports/{timestamp}/compliance-report.csv'
    
    s3_client.put_object(
        Bucket=BUCKET_NAME,
        Key=s3_key,
        Body=csv_content,
        ContentType='text/csv'
    )
    print(f"Report uploaded to s3://{BUCKET_NAME}/{s3_key}")
    
    # Count summary
    compliant = sum(1 for r in results if r['compliance'] == 'COMPLIANT')
    non_compliant = sum(1 for r in results if r['compliance'] == 'NON_COMPLIANT')
    
    # Generate presigned URL valid for 7 days
    presigned_url = s3_client.generate_presigned_url(
        'get_object',
        Params={'Bucket': BUCKET_NAME, 'Key': s3_key},
        ExpiresIn=604800
    )
    
    # Notify via SNS
    sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'Weekly Compliance Report - {timestamp}',
        Message=f"""
Weekly Tag Compliance Report Generated

Summary
-------
Total Resources Evaluated : {len(results)}
Compliant                 : {compliant}
Non-Compliant             : {non_compliant}
Compliance Rate           : {round((compliant/len(results))*100, 1) if results else 0}%

Download Report (valid 7 days):
{presigned_url}

Config Rule : {RULE_NAME}
Generated   : {timestamp} UTC
        """
    )
    
    return {
        'statusCode': 200,
        'report_key': s3_key,
        'total': len(results),
        'compliant': compliant,
        'non_compliant': non_compliant
    }


def get_compliance_results():
    results = []
    paginator = config_client.get_paginator('get_compliance_details_by_config_rule')
    
    pages = paginator.paginate(
        ConfigRuleName=RULE_NAME,
        ComplianceTypes=['COMPLIANT', 'NON_COMPLIANT']
    )
    
    for page in pages:
        for result in page['EvaluationResults']:
            qualifier = result['EvaluationResultIdentifier']['EvaluationResultQualifier']
            results.append({
                'resource_id': qualifier.get('ResourceId', ''),
                'resource_type': qualifier.get('ResourceType', ''),
                'compliance': result.get('ComplianceType', ''),
                'annotation': result.get('Annotation', ''),
                'last_evaluated': str(result.get('ResultRecordedTime', ''))
            })
    
    return results


def generate_csv(data):
    output = io.StringIO()
    if not data:
        output.write("No data found")
        return output.getvalue()
    
    writer = csv.DictWriter(output, fieldnames=data[0].keys())
    writer.writeheader()
    writer.writerows(data)
    
    return output.getvalue()
```

Click **Deploy** to save the code.

Now set environment variables. Go to **Configuration → Environment Variables → Edit → Add**:
```
BUCKET_NAME     →   org-compliance-reports-[youraccountid]
SNS_TOPIC_ARN   →   arn:aws:sns:[region]:[accountid]:compliance-report-notifications
RULE_NAME       →   required-tags-rule
