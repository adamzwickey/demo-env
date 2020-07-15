#!/bin/bash -e

: ${PARAMS_YAML?"Need to set PARAMS_YAML environment variable"}

export TKG_LAB_SCRIPTS=tkg-lab/scripts

# Management Cluster
./scripts/mgmt.sh

# Shared Services Cluster
./scripts/shared.sh

# Workload Cluster
./scripts/workload.sh

# Apps
./scripts/apps.sh