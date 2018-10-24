variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default     = 8080
}

variable "lb_ingress_port" {
  description = "The port the load balancer will use for HTTP requests"
  default     = 80
}

variable "lb_egress_port" {
  description = "The port the load balancer will use for health checks"
  default     = 0
}
