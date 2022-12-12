variable "registry_username" {
  type = string
}

variable "registry_password" {
  type = string
}

variable "instance_name" {
  type    = string
  default = "mongo-enterprise"
}

variable "instance_availability_zone" {
  type    = string
  default = "ap-southeast-1a"
}

variable "instance_blueprint_id" {
  type    = string
  default = "debian_11"
}

variable "instance_bundle_id" {
  type    = string
  default = "small_2_0"
}
