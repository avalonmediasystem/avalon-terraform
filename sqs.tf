# resource "aws_sqs_queue" "this_ui_deadletter_queue" {
#   name       = "${local.namespace}-avr-ui-dead-letter-queue"
#   fifo_queue = false
#   tags       = "${local.common_tags}"
# }

# resource "aws_sqs_queue" "this_ui_queue" {
#   name                       = "${local.namespace}-avr-ui-queue"
#   fifo_queue                 = false
#   delay_seconds              = 0
#   visibility_timeout_seconds = 3600
#   redrive_policy             = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.this_ui_deadletter_queue.arn}\",\"maxReceiveCount\":5}"
#   tags                       = "${local.common_tags}"
# }

resource "aws_sqs_queue" "this_batch_deadletter_queue" {
  name       = "${local.namespace}_batch-dead-letter-queue"
  fifo_queue = false
  tags       = "${local.common_tags}"
}

resource "aws_sqs_queue" "this_batch_queue" {
  name                       = "batch_ingest"
  fifo_queue                 = false
  delay_seconds              = 0
  visibility_timeout_seconds = 3600
  redrive_policy             = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.this_batch_deadletter_queue.arn}\",\"maxReceiveCount\":5}"
  tags                       = "${local.common_tags}"
}
