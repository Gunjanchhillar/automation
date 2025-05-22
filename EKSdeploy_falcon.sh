#!/bin/bash

# Configuration
LOG_FILE="falcon_deployment_$(date +%Y%m%d_%H%M%S).log"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Usage function
usage() {
    echo "usage: $0
Required Flags:
    -u, --client-id <FALCON_CLIENT_ID>             Falcon API OAUTH Client ID
    -s, --client-secret <FALCON_CLIENT_SECRET>     Falcon API OAUTH Client Secret
    -r, --region <FALCON_REGION>                   Falcon Cloud Region [us-1, us-2, eu-1, gov-1, or gov-2]
Optional Flags:
    --sidecar                        Deploy container sensor as sidecar
    --ebpf                           Use eBPF backend
    --skip-sensor                    Skip deployment of Falcon sensor
    --skip-kac                       Skip deployment of KAC
    --skip-iar                       Skip deployment of IAR
    --uninstall                      Uninstalls all components
    --tags <TAG1,TAG2>              Tag the Falcon sensor
    -h, --help                       Display this help message"
    exit 2
}

# Error handler
die() {
    echo "Fatal error: $*" >&2
    exit 1
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -u|--client-id)
            FALCON_CLIENT_ID="$2"
            shift 2
            ;;
        -s|--client-secret)
            FALCON_CLIENT_SECRET="$2"
            shift 2
            ;;
        -r|--region)
            FALCON_CLOUD="$2"
            shift 2
            ;;
        -t|--tags)
            SENSOR_TAGS="$2"
            shift 2
            ;;
        --ebpf)
            BACKEND="bpf"
            shift
            ;;
        --skip-sensor)
            SKIPSENSOR=true
            shift
            ;;
        --sidecar)
            SIDECAR=true
            shift
            ;;
        --skip-kac)
            SKIPKAC=true
            shift
            ;;
        --skip-iar)
            SKIPIAR=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: Unsupported flag: '$1'"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$FALCON_CLIENT_ID" || -z "$FALCON_CLIENT_SECRET" || -z "$FALCON_CLOUD" ]]; then
    die "Missing required parameters. Use -h for help."
fi

# Function to deploy Falcon sensor
deploy_falcon_sensor() {
    local cluster_name="$1"
    local region="$2"
    
    log_message "Deploying Falcon sensor to cluster: $cluster_name in region: $region"
    
    # Build command with optional flags
    local cmd="./falcon-k8s-cluster-deploy.sh"
    cmd+=" --client-id \"$FALCON_CLIENT_ID\""
    cmd+=" --client-secret \"$FALCON_CLIENT_SECRET\""
    cmd+=" --region \"$FALCON_CLOUD\""
    cmd+=" --cluster \"$cluster_name\""
    [[ -n "$BACKEND" ]] && cmd+=" --ebpf"
    [[ -n "$SIDECAR" ]] && cmd+=" --sidecar"
    [[ -n "$SENSOR_TAGS" ]] && cmd+=" --tags \"$SENSOR_TAGS\""
    [[ -n "$SKIPSENSOR" ]] && cmd+=" --skip-sensor"
    [[ -n "$SKIPKAC" ]] && cmd+=" --skip-kac"
    [[ -n "$SKIPIAR" ]] && cmd+=" --skip-iar"
    [[ -n "$UNINSTALL" ]] && cmd+=" --uninstall"
    
    eval "$cmd"
    return $?
}

# Main function to discover and process clusters
discover_and_process_clusters() {
    log_message "Starting EKS cluster discovery..."
    
    local total_clusters=0
    local successful_executions=0
    local failed_executions=0

    for region in $(aws ec2 describe-regions --output text --query 'Regions[*].RegionName'); do
        log_message "Processing region: $region"
        
        # Get clusters in region
        local clusters
        clusters=$(aws eks list-clusters --region "$region" --output text) || continue
        
        if [[ -z "$clusters" ]]; then
            log_message "No clusters found in region $region"
            continue
        fi
        
        for cluster in $clusters; do
            ((total_clusters++))
            log_message "Processing cluster: $cluster"
            
            # Check cluster status
            local cluster_status
            cluster_status=$(aws eks describe-cluster --name "$cluster" --region "$region" --query 'cluster.status' --output text)
            
            if [[ "$cluster_status" == "ACTIVE" ]]; then

            #Check for Helm Prerequisite to deploy Falcon sensor
             install_helm
  	 	     initialize_helm
   	 	     verify_helm
       
                # Update kubeconfig
                if aws eks update-kubeconfig --name "$cluster" --region "$region"; then
                    # Check if Falcon sensor is already installed
                    if ! kubectl get daemonset -A | grep -q falcon; then
                        log_message "Deploying Falcon sensor to cluster $cluster"

                        # Check custom cluster
                        if [[ "$region" == "us-east-1" ]]; then
				echo "got it"
                            if deploy_falcon_sensor "$cluster" "$region"; then
                                ((successful_executions++))
                                log_message "Successfully deployed to cluster $cluster"
				echo "deployed GC"
                            else
                                ((failed_executions++))
                                log_message "Failed to deploy to cluster $cluster"
                            fi
                        else
                            log_message "Skipping deployment for region: $region"
                            ((failed_executions++))
                        fi
                    else
                        log_message "Falcon sensor already installed on cluster $cluster"
                        ((successful_executions++))
                    fi
                else
                    log_message "Failed to get kubeconfig for cluster $cluster"
                    ((failed_executions++))
                fi
            else
                log_message "Skipping inactive cluster $cluster (status: $cluster_status)"
                ((failed_executions++))
            fi
        done
    done

    # Print summary
    log_message "Deployment Summary:"
    log_message "Total clusters found: $total_clusters"
    log_message "Successful executions: $successful_executions"
    log_message "Failed executions: $failed_executions"
}




#!/bin/bash

# Function to install Helm
install_helm() {
    if ! command -v helm &> /dev/null; then
        echo "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    else
        echo "Helm is already installed"
        helm version
    fi
}

# Function to initialize Helm
initialize_helm() {
    echo "Initializing Helm..."
    helm repo add stable https://charts.helm.sh/stable
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
}

# Function to verify Helm installation
verify_helm() {
    echo "Verifying Helm installation..."
    helm version
    helm repo list
}


verify_aws_auth() {
#echo "aws auth"
#caller_identity=$(aws sts get-caller-identity)
#echo "Full output: $caller_identity"
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "ERROR: AWS authentication failed"
        exit 1
    fi
}



# Main execution
main() {
	#verify_aws_auth
    # Validate AWS CLI access
   # if ! aws sts get-caller-identity &>/dev/null; then
       # die "Unable to authenticate with AWS"
    
   # fi
    
    # Check if falcon-k8s-cluster-deploy.sh exists and is executable
    if [[ ! -x "./falcon-k8s-cluster-deploy.sh" ]]; then
        die "falcon-k8s-cluster-deploy.sh not found or not executable"
    fi
    
    discover_and_process_clusters
    log_message "Deployment process completed"
}

# Execute main function
main
