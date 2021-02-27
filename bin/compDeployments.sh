#!/bin/bash
OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Validation:
# -----------------------------------------------------------------------------------------------------------------
_component_name=${1}
if [ -z "${_component_name}" ]; then
  echo -e \\n"Missing parameter!"\\n
  exit 1
fi
# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Check for dependancies
JQ_EXE=jq
if ! isInstalled ${JQ_EXE}; then
    echoWarning "The ${JQ_EXE} executable is required and was not found on your path."

  cat <<-EOF
	The recommended approach to installing the required package(s) is to use either [Homebrew](https://brew.sh/) (MAC)
  or [Chocolatey](https://chocolatey.org/) (Windows).

  Windows:
    - chocolatey install jq

  MAC:
    - brew install jq

EOF
    exit 1
fi

# Turn on debugging if asked
if [ ! -z "${DEBUG}" ]; then
  set -x
fi

# -----------------------------------------------------------------------------------------------------------------
# Functions:
# -----------------------------------------------------------------------------------------------------------------
generateConfigs() {
  _projectName=$(getProjectName)

  DEPLOYS=$(getDeploymentTemplates $(getTemplateDir ${_component_name}))
  # echo "Deployment templates:"
  # for deploy in ${DEPLOYS}; do
  #   echo ${deploy}
  # done
  # exit 1

  for deploy in ${DEPLOYS}; do
    echo -e \\n\\n"Processing deployment configuration; ${deploy} ..."

    _template="${deploy}"
    _template_basename=$(getFilenameWithoutExt ${deploy})
    _deploymentConfig="${_template_basename}${DEPLOYMENT_CONFIG_SUFFIX}"
    _searchPath=$(echo $(getDirectory "${_template}") | sed 's~\(^.*/openshift\).*~\1~')
    PARAM_OVERRIDE_SCRIPT=$(find ${_searchPath} -name "${_template_basename}.overrides.sh")
    _componentSettings=$(find ${_searchPath} -name "${_componentSettingsFileName}")

    if [ ! -z ${_componentSettings} ] && [ -f ${_componentSettings} ]; then
      echo -e "Loading component level settings from ${_componentSettings} ..."
      . ${_componentSettings}
    fi

    if [ ! -z "${PROFILE}" ] && [ "${PROFILE}" != "${_defaultProfileName}" ]; then
      _paramFileName="${_template_basename}.${PROFILE}"
    else
      _paramFileName="${_template_basename}"
    fi

    PARAMFILE=$(find ${_searchPath} -name "${_paramFileName}.param")
    ENVPARAM=$(find ${_searchPath} -name "${_paramFileName}.${DEPLOYMENT_ENV_NAME}.param")

    if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
      LOCALPARAM=$(find ${_searchPath} -name "${_paramFileName}.local.param")
    fi

    # echoWarning "_template: ${_template}"
    # echoWarning "_template_basename: ${_template_basename}"
    # echoWarning "_deploymentConfig: ${_deploymentConfig}"
    # echoWarning "_searchPath: ${_searchPath}"
    # echoWarning PARAM_OVERRIDE_SCRIPT: \"${PARAM_OVERRIDE_SCRIPT}\"
    # echoWarning "_componentSettings: ${_componentSettings}"
    # echoWarning "_paramFileName: ${_paramFileName}"
    # echoWarning "PARAMFILE: ${PARAMFILE}"
    # echoWarning "ENVPARAM: ${ENVPARAM}"
    # echoWarning "LOCALPARAM: ${LOCALPARAM}"
    # exit 1

    # Used to inject variables from parameter files into override scripts
    unset overrideScriptVars

    if [ -f "${PARAMFILE}" ]; then
      overrideScriptVars="${overrideScriptVars:+~}$(readConf -f -d '\~' ${PARAMFILE})"
      PARAMFILE="--param-file=${PARAMFILE}"
    else
      PARAMFILE=""
    fi

    if [ -f "${ENVPARAM}" ]; then
      overrideScriptVars+="${overrideScriptVars:+~}$(readConf -f -d '\~' ${ENVPARAM})"
      ENVPARAM="--param-file=${ENVPARAM}"
    else
      ENVPARAM=""
    fi

    if [ -f "${LOCALPARAM}" ]; then
      overrideScriptVars+="${overrideScriptVars:+~}$(readConf -f -d '\~' ${LOCALPARAM})"
      LOCALPARAM="--param-file=${LOCALPARAM}"
    else
      LOCALPARAM=""
    fi

    # echoWarning "overrideScriptVars: ${overrideScriptVars}"
    # exit 1

    # Parameter overrides can be defined for individual deployment templates at the root openshift folder level ...
    if [ ! -z ${PARAM_OVERRIDE_SCRIPT} ] && [ -f ${PARAM_OVERRIDE_SCRIPT} ]; then
      # Read the TSV key=value pairs into an array ...
      IFS='~' read -ra overrideScriptVarsArray <<< "${overrideScriptVars}"
      echo -e "Loading parameter overrides for ${deploy} ..."
      SPECIALDEPLOYPARM+=" $(env "${overrideScriptVarsArray[@]}" ${PARAM_OVERRIDE_SCRIPT})"
    fi

    if updateOperation; then
      echoWarning "Preparing deployment configuration for update/replace, removing any 'Secret' objects so existing values are left untouched ..."
      oc -n ${_projectName} process  --local --filename=${_template} ${SPECIALDEPLOYPARM} ${LOCALPARAM} ${ENVPARAM} ${PARAMFILE} \
      | jq 'del(.items[] | select(.kind== "Secret"))' \
      > ${_deploymentConfig}
      exitOnError
    elif createOperation; then
      oc -n ${_projectName}  process  --local --filename=${_template} ${SPECIALDEPLOYPARM} ${LOCALPARAM} ${ENVPARAM} ${PARAMFILE} > ${_deploymentConfig}
      exitOnError
    else
      echoError "\nUnrecognized operation, $(getOperation).  Unable to process template.\n"
      exit 1
    fi

    if [ ! -z "${SPECIALDEPLOYPARM}" ]; then
      unset SPECIALDEPLOYPARM
    fi
  done
}
# =================================================================================================================

# =================================================================================================================
# Main Script:
# -----------------------------------------------------------------------------------------------------------------
generateConfigs

echo -e \\n"Removing temporary param override files ..."
cleanOverrideParamFiles

if [ -z ${GEN_ONLY} ]; then
  echo -e \\n"Deploying deployment configuration files ..."
  deployConfigs
fi
# =================================================================================================================
