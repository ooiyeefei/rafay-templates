variable "cluster" {
  type = string
}

variable "user" {
  type = string
}

variable "app" {
  type    = string
  default = "km"
}

variable "role" {
  type    = string
  default = "ML engineer"
}
