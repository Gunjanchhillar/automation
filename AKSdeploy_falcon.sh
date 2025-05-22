
#The Script will auto discover all AKS clusters, get ocnfig details. Then iterate through each cluster to check
#whether Falcon sensor is installed as Daemonset.If installed it will skip else deploy the Daemonset Node sensor on each cluster

#!/bin/bash

usage() {
    echo "usage: $0

Required Flags:
    -u, --client-id <FALCON_CLIENT_ID>             Falcon API OAUTH Client ID
    -s, --client-secret <FALCON_CLIENT_SECRET>     Falcon API OAUTH Client Secret
    -r, --region <FALCON_REGION>                   Falcon Cloud Region [us-1, us-2, eu-1, gov-1, or gov-2]
    -c, --cluster <K8S_CLUSTER_NAME>               Cluster name
Optional Flags:
    --sidecar                        Deploy container sensor as sidecar. Existing pods must be restarted to install sidecar sensors.
    --azure                          Enables IAR scanning for ACR sourced images on Azure using default Azure config JSON file path   
    --autopilot                      For deployments onto GKE autopilot. Defaults to eBPF / User mode
    --skip-sensor                    Skip deployment of Falcon sensor
    --skip-kac                       Skip deployment of KAC (Kubernetes Admission Control)
    --skip-iar                       Skip deployment of IAR (Image at Runtime Scanning)
    --uninstall                      Uninstalls all components
    --tags <TAG1,TAG2>               Tag the Falcon sensor. Multiple tags must formatted with \, separators. e.g. --tags \"exampletag1\,exampletag2\"

Help Options:
    -h, --help display this help message"
    exit 2
}

die() {
    echo "Fatal error: $*" >&2
    exit 1
}

while [ $# != 0 ]; do
    case "$1" in
        -u|--client-id)
            if [ -n "${2:-}" ] ; then
                export FALCON_CLIENT_ID="${2}"
                shift
            fi
            ;;
        -s|--client-secret)
            if [ -n "${2:-}" ]; then
                export FALCON_CLIENT_SECRET="${2}"
                shift
            fi
            ;;
        -r|--region)
            if [ -n "${2:-}" ]; then
                FALCON_CLOUD="${2}"
                shift
            fi
            ;;
        -t|--tags)
            if [ -n "${2}" ]; then
                SENSOR_TAGS="${2}"
                shift
            fi
            ;;
        --ebpf)
            if [ -n "${1}" ]; then
                BACKEND="bpf"      
            fi
            ;;
        --skip-sensor)
            if [ -n "${1}" ]; then
                SKIPSENSOR=true
            fi
            ;;
        --sidecar)
            if [ -n "${1}" ]; then
                SIDECAR=true
            fi
            ;;
        --skip-kac)
            if [ -n "${1}" ]; then
                SKIPKAC=true
            fi
            ;;
        --skip-iar)
            if [ -n "${1}" ]; then
                SKIPIAR=true
            fi
            ;;
        --azure)
            if [ -n "${1}" ]; then
                AZURE=true
            fi
            ;;
        --autopilot)
            if [ -n "${1}" ]; then
                AUTOPILOT=true
            fi
            ;;
        --uninstall)
            if [ -n "${1}" ]; then
                UNINSTALL=true
            fi
            ;;
        -h|--help)
            if [ -n "${1}" ]; then
                usage
            fi
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -*) # unsupported flags
            >&2 echo "ERROR: Unsupported flag: '${1}'"
            usage
            ;;
    esac
    shift
done

# Get AKS clusters
clusters=$(az aks list --query '[].{name:name,resourceGroup:resourceGroup}' -o json)

for cluster in $(echo $clusters | jq -c '.[]'); do
    name=$(echo $cluster | jq -r '.name')
    rg=$(echo $cluster | jq -r '.resourceGroup')
    echo $name $rg
    
    # Get credentials
    az aks get-credentials --name $name --resource-group $rg

    if [ "$rg" = "gchhillar-TempRG" ]; then
        echo "Found it"

         # Check if Falcon sensor is already installed
                    if ! kubectl get daemonset -A | grep -q falcon; then
                        log_message "Deploying Falcon sensor to cluster $cluster"
                           sh ./falcon-k8s-cluster-deploy.sh --client-id "$FALCON_CLIENT_ID" --client-secret "$FALCON_CLIENT_SECRET" --ebpf --region "$FALCON_CLOUD" --cluster "$name"
 
            
        else
            echo "Skipping, Falcon sensor already installed"
            exit 1
        fi
    fi
done
