# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-2"
}

variable "cluster_name" {
  description = "Cluster name"
  type = string
  default = "deploy-eks-test-11"
}

variable "instance_type" {
  description = "Instance Type"
  type = string
  default = "t3a.xlarge"
}

variable "min_size" {
  description = "Min number of nodes"
  type = number
  default = 1
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
