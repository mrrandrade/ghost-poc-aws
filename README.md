# Ghost POC

Ghost POC as a cloud business case to be implemented using AWS. 

## How to run this repository

All automation in this repository was made using [Terraform](https://www.terraform.io/downloads.html). 

Since building a pipeline for Terraform wasn't the focus of the activity, I left it to be run locally, without storing backend on remote S3 bucket. 

```
# Git commands
git clone https://github.com/mrrandrade/ghost-poc.git
cd /srv/github/ghost-poc/ghost-terraform

# Terraform AWS Provider configuration
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=tF0...
export AWS_DEFAULT_REGION=us-east-1

# Terraform commands
terraform init
terraform apply -auto-approve
```

## About the software

The aforementioned software, Ghost, is an open source, professional publishing platform built on a modern Node.js technology stack. 

The main caveat about this particular software is that it's made to be run as a single instance, as [described in the official documentation](https://ghost.org/docs/faq/clustering-sharding-multi-server/). Because of this restriction, all scaling efforts have to consider only vertical scaling of the underlying hardware and other Cloud Services to optimize it's throughput and stability.

## Website - proposed architecture

The basic architecture for Ghost would require:

* A C5 EC2 instance to deploy the application;
* A M5 RDS Mysql instance;
* A S3 bucket to store images;
* A Cloudfront distribution to serve both Ghost and the images from the S3 bucket.
* A Lambda function to be run manually as a "panic button" to delete all posts, which will use a token extracted from Ghost stored in Secrets Manager.

The EC2 instance is part of an AutoScalingGroup that will be responsible to keep only 1 replica up all the time, due to application limitation. In case of "significant geographical failure", it will be able to spawn the new replica on another AZ.

The RDS instance will be deployed using Multi-AZ deployment to tolerate "significant geographical failure". 

### Disaster Recovery Plan

As a Disaster Recovery Plan, for the situation that the original region is offline, the EC2 AutoScalingGroup could be recreated on another Region easily using the Terraform Automation, which would also be able to switch the Origin configuration on the Cloudfront distribution.

RDS MySQL, unfortunately, is **not** able to automatically [send snapshots to another Region](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReplicateBackups.html). The two options would be:
* Create a Read Replica to assume as a Master database, which would be the most expensive solution;
* Create a schedule to transfer RDS snapshots to another Region.

### Implemented Architecture for the Poc

Due to limitations, I was forced to do some adjustments to the architecture to have a viable product for the Poc. 

Best approach to launch Ghost would be to have a olden AMI with it preinstalled instead of installing it using Userdata as is implemented, but there was no real convenient way to provide an AMI for this PoC, so this inferior approach was chosen.

Since there was no DNS domain to be able to register the EC2 instance, there was no easy way to point the Cloudfront distribution to the EC2 instance directly; hence, the Poc deploys an Application Load Balancer in front of the instance so it is easily configurable as an origin for Cloudfront.

Also there was not enough time to embed the S3 plugin to make Ghost able to write images to a S3 bucket.

Lambda function takes a ghost_token parameter from the Secrets Manager service; since the token does not exist until the website, the secret is configured with a throwaway value to be replaced manually after the website is installed.

## Application development environment - proposed Architecture

**Personal note**: maybe for the lack of understanding of my part, I was lost at the paragraph that describes how 5 Devops teams would be working on the project. My final decision was that it was completely separated from the website part, and Ghost would **not be** the application deployed several times per day without downtime - as it's just not possible. I believe I might have got it wrong and should probably have asked before implementing anything.

To implement these requirements, a **Kubernetes cluster** could be deployed to provide the environment for developing, production and other environments that feel needed.

Depending on the problem, more than one cluster could be build to separate production from other environments.

Observability could be provided with CloudWatch Agent installed as a Daemonset to provide Container Insights functionality, and Fluent bit to send logs to CloudWatch Logs. 

**Personal note**: unfortunately, I was not able to implement any of these automations because of time constraints - I judged it would be the best to provide a full working Ghost deployment as a PoC.

# Overview of tasks 

A complete overview of the tasks will be shown as a table below.

| Task number | Status | Description |
| ---      | ---      | ---      |
| 1 | done   | Deploy [Ghost](ghost.org) to host client's website with RDS and Cloudfront. |
| 2 | done | Deploy a Lambda function that is able to delete all posts from the site using credentials from Secrets Manager |
| 3 |  not done        | Implement RDS Snapshot upload to another Region   |
| 4 |  not done        | Implement Athena predefined queries for Security analysis of Cloudfront logs for security monitoring.  |
| 5 |  not done        | Implement Kubernetes cluster as plataform for environments for the application.  |
