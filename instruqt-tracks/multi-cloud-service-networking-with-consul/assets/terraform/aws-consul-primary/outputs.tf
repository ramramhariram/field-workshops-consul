output "aws_consul_public_ip" {
  value = aws_instance.consul.public_ip
}

output "aws_mgw_public_ip" {
  value = aws_instance.mesh_gateway.public_ip
}

output "cts-id" {
    value = "${aws_instance.cts.id}"
  }

output "cts-publicip" {
    value = "${aws_instance.cts.public_ip}"
  }
