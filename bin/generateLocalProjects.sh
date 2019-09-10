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

  ${0##*/} [options]

  Options:
  ========
    -D delete the local projects created by this script.
    -n <projectNamespace> the name of a project set
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :n:D FLAG; then
    case ${FLAG} in
      # List of local options:
      D ) export DELETE_PROJECTS=1 ;;
      n ) PROJECT_NAMESPACE=${OPTARG} ;;
      
      # Pass unrecognized options ...
      \?) 
        pass+=" -${OPTARG}"
        ;;
    esac
  else
    # Pass unrecognized arguments ...
    pass+=" ${!OPTIND}"
    let OPTIND++
  fi
done

# Pass the unrecognized arguments along for further processing ...
shift $((OPTIND-1))
set -- "$@" $(echo -e "${pass}" | sed -e 's/^[[:space:]]*//')
# =================================================================================================================

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
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
