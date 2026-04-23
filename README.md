# Lab 16 — Cloud AI Environment Setup on AWS

**Author:** Hieu1607 | **Date:** 2026-04-23 | **Region:** us-east-1

## Overview

This repository contains the Terraform code and benchmark results for **Lab 16: Cloud AI Environment Setup**. Due to GPU quota restrictions on a new AWS account, the alternative CPU path (Part 7) was used: deploying a **LightGBM** model on a `t3.micro` instance inside a private VPC.

## Architecture

```
Internet
   |
[ALB - port 80]
   |
[Public Subnet]
   |--- Bastion Host (t3.micro)
   |--- NAT Gateway
   |
[Private Subnet]
   |--- ML Node (t3.micro) — runs LightGBM benchmark
```

All infrastructure is provisioned with **Terraform** (IaC).

## Repository Structure

```
.
├── terraform/          # Terraform IaC — VPC, EC2, ALB, NAT Gateway
├── benchmark_result.json   # LightGBM benchmark metrics
├── terminal_screen.png     # Screenshot: benchmark output on EC2
├── running_instance.png    # Screenshot: AWS EC2 console
├── cost.png                # Screenshot: AWS Billing console
├── REPORT.md               # Full lab report (Vietnamese)
└── README_aws.md           # Original lab instructions
```

## Quick Start

```bash
# 1. Configure AWS credentials
aws configure

# 2. Deploy infrastructure
cd terraform
export TF_VAR_hf_token="dummy"
terraform init
terraform apply

# 3. SSH into the ML node via Bastion and run benchmark
python3 ~/ml-benchmark/benchmark.py

# 4. Destroy all resources when done (important — avoids charges)
terraform destroy
```

## Benchmark Results (t3.micro, LightGBM)

| Metric | Result |
|---|---|
| Load time | 0.025 s |
| Training time | 0.40 s |
| AUC-ROC | **0.9843** |
| Accuracy | **0.9475** |
| F1-Score | **0.947** |
| Inference latency (1 row) | 0.059 ms |

## Cost Estimate (1 hour, us-east-1)

| Service | Cost/hr |
|---|---|
| EC2 t3.micro x2 | ~$0.000 (Free Tier) |
| NAT Gateway | ~$0.045 |
| ALB | ~$0.008 |
| **Total** | **~$0.053** |

## Notes

- GPU quota (g4dn.xlarge) was unavailable on a new AWS account — the CPU fallback path (Part 7 of the lab) was used instead.
- AWS Billing data requires ~24 hours to populate on a new account; the billing screenshot shows the initial "data not yet available" state.
- Run `terraform destroy` immediately after completing the lab to avoid ongoing NAT Gateway and ALB charges.
