variable "region" {
    default = "us-east-1"
}
variable "name" {
    type        = "string"
    description = "Name  (e.g. `app` or `cluster`)"
}

variable "application" {
    type        = "string"
    description = "Application (e.g. `cd` or `clouddrove`)"
}

variable "environment" {
    type        = "string"
    description = "Environment (e.g. `prod`, `dev`, `staging`)"
}

variable "vpc_id" {
    type        = "string"
    description = ""
}

variable "source_ip" {
    type        = "list"
    description = ""
}

variable "instance_type" {
    type        = "string"
    description = ""
    default     = "t2.micro"
}

variable "key_name" {
    type        = "string"
    description = ""
}

variable "ami_id" {
    type        = "string"
    description = ""
}

variable "subnet" {
    type        = "string"
    description = ""
}

variable "disk_size" {
    description = "Size of the root volume in gigabytes"
    default     = "8"
}

variable "user_data_base64" {
    type        = "string"
    description = "The Base64-encoded user data to provide when launching the instances"
    default     = ""
}
