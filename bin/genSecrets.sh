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

  Usage:
    ${0##*/} [options]
EOF
}

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
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
  
  oc -n ${_PROJECT_NAME} process  --local --filename=${_template} ${PARAMFILE} > ${_configFile}
  exitOnError
  
  # Always remove the temporay parameter file ...
  if [ -f "${_paramFile}" ]; then
    rm ${_paramFile}
  fi

  if [ -z ${GEN_ONLY} ]; then
    oc -n ${_PROJECT_NAME} $(getOcAction) -f ${_configFile}
    exitOnError
  fi

  # Delete the temp config file if the keep command line option was not specified
  if [ -z "${KEEPJSON}" ]; then
    rm ${_configFile}
  fi
}
# ==============================================================================

_OUTPUT_DIR=$(getRelativeOutputDir)
_PROJECT_NAME=$(getProjectName)

echo -e \\n"Deploying secret(s) into the ${DEPLOYMENT_ENV_NAME} (${_PROJECT_NAME}) environment ..."\\n

# Get list of all of the secret templates in the project ...
pushd ${PROJECT_DIR} >/dev/null
_templates=$(getSecretTemplates)
for _template in ${_templates}; do 
  processSecret ${_template}
done
popd >/dev/null