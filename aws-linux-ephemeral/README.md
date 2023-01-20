---
name: Develop in Linux on AWS EC2 (Ephemeral, Persistent Home)
description: Get started with Linux development on AWS EC2.
tags: [cloud, aws]
icon: /icon/aws.png
---

# aws-linux-ephemeral

This template gives developers ephemeral AWS instances. When a workspace is restarted, all data is lost except files in `/home/coder/` which is persisted by a seperate EBS volume.

To add software (e.g. Java), you have a few options:

1. Template authors can install software in the [startup_script](https://github.com/bpmct/coder-templates/blob/b804db6da6e2702058d38148f1b9d44a23e83c1e/aws-linux-ephemeral/main.tf#L82)
1. Template authors can build [custom AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-ebs.html) which include all packages. New template versions can reference the new AMI, even in [build pipelines](http://coder.com/docs/v2/latest/templates/change-management).
1. Developers can add an executable `personalize` script in their home directory to install unique software.

To get started, run `coder templates init`. When prompted, select this template.
Follow the on-screen instructions to proceed.

## Authentication

This template assumes that coderd is run in an environment that is authenticated
with AWS. For example, run `aws configure import` to import credentials on the
system and user running coderd. For other ways to authenticate [consult the
Terraform docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration).

## Required permissions / policy

The following sample policy allows Coder to create EC2 instances and modify
instances provisioned by Coder:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VisualEditor0",
      "Effect": "Allow",
      "Action": [
        "ec2:GetDefaultCreditSpecification",
        "ec2:DescribeIamInstanceProfileAssociations",
        "ec2:DescribeTags",
        "ec2:CreateTags",
        "ec2:RunInstances",
        "ec2:DescribeInstanceCreditSpecifications",
        "ec2:DescribeImages",
        "ec2:ModifyDefaultCreditSpecification",
        "ec2:DescribeVolumes"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CoderResources",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceAttribute",
        "ec2:UnmonitorInstances",
        "ec2:TerminateInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:DeleteTags",
        "ec2:MonitorInstances",
        "ec2:CreateTags",
        "ec2:RunInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyInstanceCreditSpecification"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Coder_Provisioned": "true"
        }
      }
    }
  ]
}
```

## code-server

`code-server` is installed via the `startup_script` argument in the `coder_agent`
resource block. The `coder_app` resource is defined to access `code-server` through
the dashboard UI over `localhost:13337`.
