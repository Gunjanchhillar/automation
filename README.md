# Automation
All automation related scripts

# Falcon Kubernetes Deployment Script

## Overview
This script automates the deployment of CrowdStrike Falcon sensors across multiple EKS clusters. It includes functionality for sensor deployment, Kubernetes Admission Controller (KAC), and Image Assessment and Response (IAR) components.

## Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Helm 3.x
- CrowdStrike Falcon API credentials
- `falcon-k8s-cluster-deploy.sh` script in the same directory

## Installation
1. Download the script
2. Make it executable:
```bash
chmod +x deploy_falcon.sh
```

## Usage EKS/AKS
```bash
./EKSdeploy_falcon.sh/ -u <FALCON_CLIENT_ID> -s <FALCON_CLIENT_SECRET> -r <FALCON_REGION> [OPTIONS]
./AKSdeploy_falcon.sh -u <FALCON_CLIENT_ID> -s <FALCON_CLIENT_SECRET> -r <FALCON_REGION> [OPTIONS]

```

### Required Flags
| Flag | Description |
|------|-------------|
| `-u, --client-id` | Falcon API OAUTH Client ID |
| `-s, --client-secret` | Falcon API OAUTH Client Secret |
| `-r, --region` | Falcon Cloud Region (us-1, us-2, eu-1, gov-1, or gov-2) |

### Optional Flags
| Flag | Description |
|------|-------------|
| `--sidecar` | Deploy container sensor as sidecar |
| `--ebpf` | Use eBPF backend |
| `--skip-sensor` | Skip deployment of Falcon sensor |
| `--skip-kac` | Skip deployment of KAC |
| `--skip-iar` | Skip deployment of IAR |
| `--uninstall` | Uninstalls all components |
| `--tags` | Tag the Falcon sensor (comma-separated) |
| `-h, --help` | Display help message |

## Features
- Automatic EKS cluster discovery
- Region-based deployment
- Helm prerequisite verification
- Comprehensive logging
- Deployment status tracking
- Error handling and reporting

## Logging
The script creates detailed logs in the format:
```
falcon_deployment_YYYYMMDD_HHMMSS.log
```

## Example
```bash
./deploy_falcon.sh \
  --client-id "ABCD123" \
  --client-secret "XYZ789" \
  --region "us-1" \
  --tags "prod,eks" \
  --ebpf
```

## Output
The script provides a deployment summary including:
- Total clusters found
- Successful executions
- Failed executions
- Detailed logs of each operation

## Error Handling
- Validates required parameters
- Checks AWS authentication
- Verifies prerequisite tools
- Handles deployment failures gracefully

## Support
For issues or questions, please contact your CrowdStrike support representative.

## License
Proprietary - CrowdStrike Inc.