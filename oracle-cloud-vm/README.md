---
name: Develop in an Oracle Cloud VM
description: Get started with a development environment on Oracle Cloud.
tags: [self-hosted, vm, oracle-cloud, code-server]
---

# oracle-cloud-vm

## Getting started

Requirements:

- A [Coder](https://github.com/coder/coder) deployment
- An Oracle Cloud account
  - Oracle cloud's [free tier](https://www.oracle.com/cloud/free/) is quite generous, including ARM VMs
- Environment variables on your Coder deployment to [authenticate with Oracle Cloud API](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformproviderconfiguration.htm#environmentVariables)

```sh
git clone https://github.com/bpmct/coder-templates
cd coder-templates/oracle-cloud-vm

# optional: modify the template
vim main.tf

coder templates create
```

## Authentication

Coder will authenticate with

## How it works
