Architecture Overview:
EventBridge (weekly cron) → Lambda → S3 (report stored) → SNS (email notification)

<img width="1304" height="617" alt="image" src="https://github.com/user-attachments/assets/df37b9ed-4aba-49f1-bbdc-57f2ea5f54e1" />

Most teams use Config rules for reporting and visibility first, then layer in the preventive deny policy once they've cleaned up existing non-compliant resources.
SCP Policy = preventive
Config rule = Detective
