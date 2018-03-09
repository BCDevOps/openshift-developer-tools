#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# ===================================================================================================
# Funtions
# ---------------------------------------------------------------------------------------------------
usage() {
  cat <<EOF
========================================================================================
Creates/Deletes a local project set in OpenShift
----------------------------------------------------------------------------------------
Usage:

  ${0} [-h -x -D]

  OPTIONS:
  ========
    -D delete the local projects created by this script.
    -h prints the usage for the script
    -n <projectNamespace> the name of a project set
    -p <profile> load a specific settings profile; setting.<profile>.sh
    -P Use the default settings profile; settings.sh.  Use this flag to ignore all but the default 
       settings profile when there is more than one settings profile defined for a project.    
    
    -x run the script in debug mode to see what's happening

  Update settings.sh and settings.local.sh files to set defaults
EOF
exit 1
}

while getopts xhn:p:PD FLAG; do
  case $FLAG in
    D ) export DELETE_PROJECTS=1 ;;
    x ) export DEBUG=1 ;;
    n ) PROJECT_NAMESPACE=$OPTARG ;;
    p ) export PROFILE=$OPTARG ;;
    P ) export IGNORE_PROFILES=1 ;;
    h ) usage ;;
    \?) #unrecognized option - show help
      echo -e \\n"Invalid script option"\\n
      usage
      ;;
  esac
done

# Shift the parameters in case there any more to be used
shift $((OPTIND-1))

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

if [ ! -z "${DEBUG}" ]; then
  set -x
fi
# ===================================================================================================

if ! isLocalCluster; then
  echo "This script can only be run on a local cluster!"
  exit 1
fi

TOOLS="${TOOLS:-${PROJECT_NAMESPACE}-tools}"
DEV="${DEV:-dev}"
TEST="${TEST:-test}"
PROD="${PROD:-prod}"

# Iterate through Tools, Dev, Test and Prod projects and create them if they don't exist.
for project in ${TOOLS} ${PROJECT_NAMESPACE}-${DEV} ${PROJECT_NAMESPACE}-${TEST} ${PROJECT_NAMESPACE}-${PROD}; do

  if [ -z ${DELETE_PROJECTS} ]; then
    # Create ..."
    createLocalProject.sh \
      -p ${project}
    exitOnError
  else
    # Delete ..."
    deleteLocalProject.sh \
      -p ${project}
    exitOnError
  fi
done

# ToDo:
# - Run the build and deployment generation too.
