

service_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

key_prefix "consul-terraform-sync/" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}
