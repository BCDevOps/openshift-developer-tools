#!/bin/bash
OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Validation:
# -----------------------------------------------------------------------------------------------------------------
_component_name=${1}
if [ -z "${_component_name}" ]; then
  echo -e \\n"Missing parameter"\\n
  exit 1
fi

# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Turn on debugging if asked
if [ ! -z "${DEBUG}" ]; then
  set -x
fi

# -----------------------------------------------------------------------------------------------------------------
# Functions:
# -----------------------------------------------------------------------------------------------------------------
generateBuildConfigs() {

  # Suppress the error message from getBuildTemplates when no search path is returned by getTemplateDir
  BUILDS=$(getBuildTemplates $(getTemplateDir ${_component_name}) 2>/dev/null || "")

  # echo "Build templates:"
  # for build in ${BUILDS}; do
  #   echo ${build}
  # done
  # exit 1

  for build in ${BUILDS}; do
    echo -e \\n"Processing build configuration; ${build}..."

    _template="${build}"
    _template_basename=$(getFilenameWithoutExt ${build})
    _buildConfig="${_template_basename}${BUILD_CONFIG_SUFFIX}"
    _searchPath=$(echo $(getDirectory "${_template}") | sed 's~\(^.*/openshift\).*~\1~')

    if [ ! -z "${PROFILE}" ] && [ "${PROFILE}" != "${_defaultProfileName}" ]; then
      _paramFileName="${_template_basename}.${PROFILE}"
    else
      _paramFileName="${_template_basename}"
    fi

    PARAMFILE=$(find ${_searchPath} -name "${_paramFileName}.param")
    if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
      LOCALPARAM=$(find ${_searchPath} -name "${_paramFileName}.local.param")
    fi

    if [ -f "${PARAMFILE}" ]; then
      PARAMFILE="--param-file=${PARAMFILE}"
    else
      PARAMFILE=""
    fi

    if [ -f "${LOCALPARAM}" ]; then
      LOCALPARAM="--param-file=${LOCALPARAM}"
    else
      LOCALPARAM=""
    fi

    oc process  --local --filename=${_template} ${LOCALPARAM} ${PARAMFILE} > ${_buildConfig}
    exitOnError
  done
}
# =================================================================================================================

# =================================================================================================================
# Main Script:
# -----------------------------------------------------------------------------------------------------------------
generateBuildConfigs

#setup artifactory/docker pull creds
if [ ! -z ${USE_PULL_CREDS} ] && [ ${USE_PULL_CREDS} = true ]; then
  echo "BUILDING PULL CREDS"
  if [ -z ${CRED_SEARCH_NAME} ]; then
    buildPromptCreds ${PROJECT_NAMESPACE} ${PULL_CREDS} ${DOCKER_REG} "${CRED_ENVS[@]}" ${DOCKER_USERNAME} ${DOCKER_PASSWORD}
  else
    buildCreds ${PROJECT_NAMESPACE} ${CRED_SEARCH_NAME} ${PULL_CREDS} ${DOCKER_REG} "${CRED_ENVS[@]}"
  fi
fi

if [ -z ${GEN_ONLY} ]; then
  echo -e \\n"Deploying build configuration files ..."
  deployBuildConfigs
fi
# =================================================================================================================