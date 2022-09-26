resource "aws_sns_topic" "notify" {
  name = "${local.namespace}-sns-notify"
}

#resource "aws_sns_topic_subscription" "notify_sms" {
#  topic_arn = aws_sns_topic.notify.arn
#  protocol  = "sms"
#  endpoint  = var.sms_notification
#}
