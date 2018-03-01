#!/bin/bash

# ==============================================================================
# Script for setting up an OpenShift cluter in Docker for Windows
#
# * Requires the OpenShift Origin CLI
#
# todo:
# Path based on platform;
# Windows; /var/lib/origin/data
# MAC; /private/var/lib/origin/data
# ------------------------------------------------------------------------------
#
# Usage:
#  
# oc-cluster-up.sh
#
# ==============================================================================
export MSYS_NO_PATHCONV=1
oc cluster up --metrics=true --host-data-dir=/var/lib/origin/data --use-existing-config