resource "random_string" "result" {
  length  = 16
  upper   = true
  lower   = true
  numeric  = true
  special = false
}

output "result" {
  value = random_string.result.result
}
