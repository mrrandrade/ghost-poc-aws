locals {

  tag_prefix = "ghost-client-xyz.com"
  application_id = "ghost-poc"
  cost_center = "poc"

  tags  = {
    "${local.tag_prefix}/application_id" = local.application_id
    "${local.tag_prefix}/environment" = "PROD"
    "${local.tag_prefix}/cost_center" = local.cost_center
  }

}

variable vpc_name {
    description = "Ghost's VPC name"
    type = string

    default = "Ghost's VPC"

}
variable vpc_cidr {
    description = "Ghost's VPC CIDR"
    type = string

    default = "10.0.0.0/16"
}

variable vpc_public_cidr {
    description = "Ghost's public CIDR"
    type = list(string)

    default = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable vpc_private_cidr {
    description = "Ghost's VPC CIDR"
    type = list(string)

    default = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"] 
}

variable vpc_database_cidr {
    description = "Ghost's VPC Database CIDR"
    type = list(string)

    default = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"] 
}

variable vpc_azs {
    description = "Ghost's VPC AZ's"
    type = list(string)

    default = ["us-east-1a", "us-east-1b", "us-east-1f"]
    # default = ["us-west-2a", "us-west-2b", "us-west-2c"]

}

variable ghost_instance_type {
  description = "EC2 Instance type for Ghost"
  type = string
  default = "t3.micro"
}

# 
# RDS
# 

variable db_admin_username {
  description = "Admin user for the Database Instance"
  type = string
  
  default = "root"
}  

variable db_admin_password {
  description = "Admin user for the Database Instance"
  type = string
  sensitive = true 
  
  # Define variable as environment variable: 
  # export TF_VAR_db_admin_password=z0mgPass0rd
  # default = "z0mgPass0rd"
}  

variable "ghost_token" {
  description = "Ghost token that is able to delete all posts and tags"
  type = string
  sensitive = true

  # This should actually be defined after one creates the blog.
  # The variable will be created with a throaway token just to it gets updated after.
  # In an ideal project, another lambda would be created where the user could trigger it with its username and password 
  # and it would retrieve the token and would populate Secrets Manager variable by itself.
  default = "616c636dc90e1d0ed45403ca:8a36ad4b2eb81c50417241cf8361fe4634bbcb0f91e3059d3b0137a3fed58551"

}
