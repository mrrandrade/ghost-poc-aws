
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>3.61.0"
    }
  }
}

# Primary and default zone
provider "aws" {
  # The provider without alias will be selected by default.
  region = "us-east-1"
  # region = "us-west-2"  

}

# Secondary Zone for Disaster Recovery
provider "aws" {
  alias = "dr-zone"
  region = "us-west-2"
}