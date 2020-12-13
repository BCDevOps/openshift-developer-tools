#!/bin/bash

# ================================================================================================================
# Usage 
# ----------------------------------------------------------------------------------------------------------------
# This is the base script for ALL *.overrides.sh implementations.  It contains uility and initialization functions
# for your *.overrides.sh script.
#
# To use this script, add the following code to the TOP of your *.overrides.sh script:
#
# _includeFile=$(type -p overrides.inc)
# if [ ! -z ${_includeFile} ]; then
#   . ${_includeFile}
# else
#   _red='\033[0;31m'; _yellow='\033[1;33m'; _nc='\033[0m'; echo -e \\n"${_red}overrides.inc could not be found on the path.${_nc}\n${_yellow}Please ensure the openshift-developer-tools are installed on and registered on your path.${_nc}\n${_yellow}https://github.com/BCDevOps/openshift-developer-tools${_nc}"; exit 1;
# fi
# ================================================================================================================

# ================================================================================================================
# Functions
# ----------------------------------------------------------------------------------------------------------------
toLower() {
  echo $(echo ${@} | tr '[:upper:]' '[:lower:]')
}

printStatusMsg(){
  (
    _msg=${1}
    _yellow='\033[1;33m'
    _nc='\033[0m' # No Color
    printf "\n${_yellow}${_msg}\n${_nc}" >&2
  )
}

getOperation() {
  (
    echo $(toLower ${OPERATION})
  )
}

createOperation() {
  (
    action=$(getOperation)
    if [ ${action} = "create" ]; then
      return 0
    else
      return 1
    fi
  )
}

updateOperation() {
  (
    action=$(getOperation)
    if [ ${action} = "update" ]; then
      return 0
    else
      return 1
    fi
  )
}

readParameter(){
  (
    _msg=${1}
    _paramName=${2}
    _defaultValue=${3}
    _encode=${4}

    _yellow='\033[1;33m'
    _nc='\033[0m' # No Color
    _message=$(echo -e "\n${_yellow}${_msg}\n${_nc}")

    read -r -p $"${_message}" ${_paramName}

    writeParameter "${_paramName}" "${_defaultValue}" "${_encode}"
  )
}

writeParameter(){
  (
    _paramName=${1}
    _defaultValue=${2}
    _encode=$(toLower ${3})

    if [ ! -z "${_encode}" ] && [ "${_encode}" = "true" ] ; then
      # The key/value pair must be contained on a single line
      _encodedValue=$(echo -n "${!_paramName:-${_defaultValue}}"|base64 -w 0)
      echo "${_paramName}=${_encodedValue}" >> ${_overrideParamFile}
    else
      echo "${_paramName}=${!_paramName:-${_defaultValue}}" >> ${_overrideParamFile}
    fi
  )
}

parseHostnameParameter(){
  (
    _sourceParamName=${1}
    _destParamName=${2}
    # Parses the host name from the url contained in the source parameter, and writes the value into the destination parameter.
    eval ${_destParamName}=$(getHostname $(getParameter ${_sourceParamName}))
    printStatusMsg "Parsing ${_destParamName} from ${_sourceParamName}; '$(getParameter ${_sourceParamName})' => '${!_destParamName}' ..."
    writeParameter "${_destParamName}" "${!_destParamName}" "false"
  )
}

getParameter(){
  (
    _paramName=${1}
    # Reads a parameter from the override param file.
    echo $(grep ${_paramName} $"${_overrideParamFile}" | awk -F= '{print $2}')
  )
}

getHostname(){
  (
    _url=${1}
    # Extract the host name from a url.
    echo $(echo ${_url} | awk -F[/:] '{print $4}')
  )
}

generateKey(){
  (
    _length=${1:-48}
    # Format can be `-base64` or `-hex`
    _format=${2:--base64}

    echo $(openssl rand ${_format} ${_length})
  )
}

generateSeed(){
  (
    _prefix=${1}
    _seed=$(echo "${_prefix}$(generateKey 32)" | fold -w 32 | head -n 1 )
    _seed=$(echo -n "${_seed}")
    echo ${_seed}
  )
}

generateUsername() {
  # Generate a random username ...
  _userName=User_$( generateKey | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1 )
  _userName=$(echo -n "${_userName}")
  echo ${_userName}
}

generatePassword() {
  # Generate a random password ...
  _password=$( generateKey | LC_CTYPE=C tr -dc 'a-zA-Z0-9_' | fold -w 20 | head -n 1 )
  _password=$(echo -n "${_password}")
  echo ${_password}
}

generateConfigMap() {  
  _config_map_name=${1}
  _source_file=${2}
  _output_format=${3}
  _output_file=${4}
  if [ -z "${_config_map_name}" ] || [ -z "${_source_file}" ] || [ -z "${_output_format}" ] || [ -z "${_output_file}" ]; then
    echo -e \\n"generateConfigMap; Missing parameter!"\\n
    exit 1
  fi

  # Auto-detect env files ....
  extension="${_source_file##*.}"
  if [ ! -z "${extension}" ] && [[ "${extension}" == "env" ]]; then
    _from_file_type="--from-env-file"
  else
    _from_file_type="--from-file"
  fi
  
  oc create configmap ${_config_map_name} ${_from_file_type} ${_source_file} --dry-run -o ${_output_format} > ${_output_file}
}

initialize(){
  # Define the name of the override param file.
  _scriptName=$(basename ${0%.*})
  export _overrideParamFile=${_scriptName}.param

  printStatusMsg "Initializing ${_scriptName} ..."

  # Remove any previous version of the file ...
  if [ -f ${_overrideParamFile} ]; then
    printStatusMsg "Removing previous copy of ${_overrideParamFile} ..."
    rm -f ${_overrideParamFile}
  fi
}
# ================================================================================================================

# ================================================================================================================
# Initialization ...
# ----------------------------------------------------------------------------------------------------------------
initialize
# ================================================================================================================