#!/bin/bash

OCTOOLSBIN=$(dirname $0)
# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  A tool to create or update OpenShift secrets.
  
  This process is a bit more flexible than using the 'oc secrets' command directly,
  in that it allows you to update existing secrets, and create more customized templates.
    
  The secret templates should be located with their related component template(s).
  The name of the template MUST be in the form <TemplateName/>-secret.json
  The values for the secrets must be stored in files in plain text, and the files
  MUST be stored in a 'secrets' folder under the project's root openshift directory.
  The name of the folder MUST match the name of the template; i.e. './openshift/secrets/<TemplateName/>-secret'
  The name of the files MUST match the name of the matching parameter in the template, where '.' in the
  filename will be replaced with '_' when converted to a parameter name.  Parameter names in the template
  should be in all caps, as the names will be converted to all caps when generated from the filename.
  
  Your project should define a .gitignore for 'secrets' so you do not accidentally commit your secrets to
  source control.
  
  Example:
  
  Template:
    ./openshift/templates/server/server-secret.json
  Containing Parameters:
    DISTRICTS_JSON
    REGIONS_JSON
    USERS_JSON
  Files Containing the plain text secrets:
    ./openshift/secrets/server-secret/districts.json
    ./openshift/secrets/server-secret/regions.json
    ./openshift/secrets/server-secret/users.json 

  Usage: $0 [ -h -u -k -g -x ]

  OPTIONS:
  ========
    -h prints the usage for the script
    -e <Environment> the environment (dev/test/prod) into which you are deploying (default: ${DEPLOYMENT_ENV_NAME})
    -u update OpenShift build configs vs. creating the configs
    -k keep the json produced by processing the template
    -x run the script in debug mode to see what's happening
    -g process the templates and generate the configuration files, but do not create or update them
       automatically set the -k option

    Update settings.sh and settings.local.sh files to set defaults
EOF
exit 1
}
# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
while getopts e:ukxhg FLAG; do
  case $FLAG in
    e ) export DEPLOYMENT_ENV_NAME=$OPTARG ;;
    u ) export OC_ACTION=replace ;;
    k ) export KEEPJSON=1 ;;
    x ) export DEBUG=1 ;;
    g ) export KEEPJSON=1
        export GEN_ONLY=1
      ;;
    h ) usage ;;
    \?) #unrecognized option - show help
      echo -e \\n"Invalid script option"\\n
      usage
      ;;
  esac
done

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
# -----------------------------------------------------------------------------------------------------------------
# Function(s):
# -----------------------------------------------------------------------------------------------------------------
getSecretParamName () {
  _secretFile=${1}
  if [ -z "${_secretFile}" ]; then
    echo -e \\n"getSecretParamName; Missing parameter!"\\n
    exit 1
  fi
  
  _filename=$(basename ${_secretFile})
  _paramName=$(echo ${_filename} | tr '[:lower:]' '[:upper:]' | sed "s~\.~_~g")  
  echo ${_paramName}  
}

getSecretParamValue () {
  _secretFile=${1}
  if [ -z "${_secretFile}" ]; then
    echo -e \\n"getSecretParamValue; Missing parameter!"\\n
    exit 1
  fi
  
  # Base64 encode and remove all whitespace ...
  _paramValue=$(cat ${_secretFile}|base64|tr -d " \t\n\r")
  echo ${_paramValue}
}

getSecretParamKeyValuePair () {
  _secretFile=${1}
  if [ -z "${_secretFile}" ]; then
    echo -e \\n"getSecretParamKeyValuePair; Missing parameter!"\\n
    exit 1
  fi

  _name=$(getSecretParamName ${_secretFile})
  _value=$(getSecretParamValue ${_secretFile})
  _param="${_name}=${_value}"
  echo ${_param}
}

createSecretParamFile () {
  _template=${1}
  if [ -z "${_template}" ]; then
    echo -e \\n"createSecretParamFile; Missing parameter!"\\n
    exit 1
  fi
  
  _name=$(getFilenameWithoutExt ${_template})
  _output="${_OUTPUT_DIR}/${_name}.secret.param"  
  _secretFiles=$(getSecretFiles ${_template})  
    
  # Generate the parameter file ...
  echo -e "#=========================================================" > ${_output}
  echo -e "# OpenShift template parameters for:" >> ${_output}
  echo -e "# JSON Template File: ${_template}" >> ${_output}
  echo -e "#=========================================================" >> ${_output}

  # Write the secrets into the parameter file ...
  for _secretFile in ${_secretFiles}; do
    _keyValuePair=$(getSecretParamKeyValuePair ${_secretFile})
    echo -e "${_keyValuePair}" >> ${_output}
  done

  echo ${_output}
}

getSecretConfigFilename () {
  _template=${1}
  if [ -z "${_template}" ]; then
    echo -e \\n"getSecretConfigFilename; Missing parameter!"\\n
    exit 1
  fi
  
  _name=$(getFilenameWithoutExt ${_template})
  _configFileName="${_OUTPUT_DIR}/${_name}_SecretConfig.json"
  echo ${_configFileName}  
}

processSecret () {
  _template=${1}
  if [ -z "${_template}" ]; then
    echo -e \\n"processSecret; Missing parameter!"\\n
    exit 1
  fi

  echo -e \\n"Processing secret configuration; ${_template} ..."
  
  # Get the related secrets and convert them into template parameters ...
  _paramFile=$(createSecretParamFile ${_template})
  _configFile=$(getSecretConfigFilename ${_template})
  
  if [ -f "${_paramFile}" ]; then
    PARAMFILE="--param-file=${_paramFile}"
  else
    PARAMFILE=""
  fi
  
  oc process --filename=${_template} ${PARAMFILE} > ${_configFile}
  exitOnError
  
  # Always remove the temporay parameter file ...
  if [ -f "${_paramFile}" ]; then
    rm ${_paramFile}
  fi

  if [ -z ${GEN_ONLY} ]; then
    oc ${OC_ACTION} -f ${_configFile}
    exitOnError
  fi

  # Delete the temp config file if the keep command line option was not specified
  if [ -z "${KEEPJSON}" ]; then
    rm ${_configFile}
  fi
}
# ==============================================================================

_OUTPUT_DIR=$(getRelativeOutputDir)

echo -e \\n"Deploying secret(s) into the ${DEPLOYMENT_ENV_NAME} (${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME}) environment ..."\\n

# Switch to the selected project ...
oc project ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME} >/dev/null
exitOnError

# Get list of all of the secret templates in the project ...
pushd ${PROJECT_DIR} >/dev/null
_templates=$(getSecretTemplates)
for _template in ${_templates}; do 
  processSecret ${_template}
done
popd >/dev/null