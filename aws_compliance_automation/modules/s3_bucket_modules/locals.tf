locals {
  create_logging = var.enable_server_access_logging && var.logging_target_bucket != null

  create_bucket_policy = var.enable_ssl_only_policy || var.additional_bucket_policy_json != null

  lambda_notifications_with_permission = {
    for name, cfg in var.lambda_notifications : name => cfg
    if try(cfg.create_permission, false)
  }

  sqs_notifications_with_policy = {
    for name, cfg in var.sqs_notifications : name => cfg
    if try(cfg.create_policy, false)
  }

  sns_notifications_with_policy = {
    for name, cfg in var.sns_notifications : name => cfg
    if try(cfg.create_policy, false)
  }
}
