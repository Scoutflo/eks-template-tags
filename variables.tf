# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Cluster name"
  type = string
  default = "ingresstesting-1"
}

variable "instance_type" {
  description = "Instance Type"
  type = string
  default = "t3a.large"
}

variable "min_size" {
  description = "Min number of nodes"
  type = number
  default = 2
}

variable "max_size" {
  description = "Max number of nodes"
  type = number
  default = 5
}

variable "desired_size" {
  description = "Desired number of nodes"
  type = number
  default = 3
}
