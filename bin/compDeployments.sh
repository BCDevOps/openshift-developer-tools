#!/bin/bash

OCTOOLSBIN=$(dirname $0)

_component_name=${1}
if [ -z "${_component_name}" ]; then
  echo -e \\n"Missing parameter!"\\n
  exit 1
fi

# Components can specify settings overrides ...
# TODO:
# Refactor how the component level overrides are loaded.
# Load them like the Parameter overrides loaded from the PARAM_OVERRIDE_SCRIPT
if [ -f ${_componentSettingsFileName} ]; then
  echo -e "Loading component level settings from ${PWD}/${_componentSettingsFileName} ..."
  . ${_componentSettingsFileName}
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Turn on debugging if asked
if [ ! -z "${DEBUG}" ]; then
  set -x
fi

# Get list of JSON files - could be in multiple directories below
# To Do: Remove the change into TEMPLATE_DIR - just find all deploy templates
pushd ${TEMPLATE_DIR} >/dev/null
DEPLOYS=$(find . -name "*.json" -exec grep -l "DeploymentConfig" '{}' \; | sed "s/.json//" | xargs | sed "s/\.\///g")
popd >/dev/null

# Switch to Tools Project
oc project ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME} >/dev/null
exitOnError

# Local params file path MUST be relative...Hack!
LOCAL_PARAM_DIR=${PROJECT_OS_DIR}

for deploy in ${DEPLOYS}; do
  echo -e \\n"Processing deployment configuration; ${deploy} ..."

  JSONFILE="${TEMPLATE_DIR}/${deploy}.json"
  JSONTMPFILE=$( basename ${deploy}_DeploymentConfig.json )
  PARAMFILE=$( basename ${deploy}.param )
  ENVPARAM=$( basename ${deploy}.${DEPLOYMENT_ENV_NAME}.param )
  PARAM_OVERRIDE_SCRIPT=$( basename ${deploy}.overrides.sh ) 
  
  if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
    LOCALPARAM=${LOCAL_PARAM_DIR}/$( basename ${deploy}.local.param )
  fi
  
  if [ -f "${PARAMFILE}" ]; then
    PARAMFILE="--param-file=${PARAMFILE}"
  else
    PARAMFILE=""
  fi

  if [ -f "${ENVPARAM}" ]; then
    ENVPARAM="--param-file=${ENVPARAM}"
  else
    ENVPARAM=""
  fi

  if [ -f "${LOCALPARAM}" ]; then
    LOCALPARAM="--param-file=${LOCALPARAM}"
  else
    LOCALPARAM=""
  fi
  
  # Parameter overrides can be defined for individual deployment templates at the root openshift folder level ...
  if [ -f ${PARAM_OVERRIDE_SCRIPT} ]; then
    if [ -z "${SPECIALDEPLOYPARM}" ]; then
      echo -e "Loading parameter overrides for ${deploy} ..."
      SPECIALDEPLOYPARM=$(${PWD}/${PARAM_OVERRIDE_SCRIPT})
    else
      echo -e "Adding parameter overrides for ${deploy} ..."
      SPECIALDEPLOYPARM="${SPECIALDEPLOYPARM} $(${PWD}/${PARAM_OVERRIDE_SCRIPT})"
    fi
  fi

  oc process --filename=${JSONFILE} ${SPECIALDEPLOYPARM} ${LOCALPARAM} ${ENVPARAM} ${PARAMFILE} > ${JSONTMPFILE}
  exitOnError
  
  if [ ! -z "${SPECIALDEPLOYPARM}" ]; then
    unset SPECIALDEPLOYPARM
  fi
     
  if [ -z ${GEN_ONLY} ]; then
    oc ${OC_ACTION} -f ${JSONTMPFILE}
    exitOnError
  fi

  # Delete the tempfile if the keep command line option was not specified
  if [ -z "${KEEPJSON}" ]; then
    rm ${JSONTMPFILE}
  fi
done
