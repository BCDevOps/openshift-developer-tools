#!/bin/bash
export MSYS_NO_PATHCONV=1
SCRIPT_HOME="$( cd "$( dirname "$0" )" && pwd )"

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  Tool to convert configuration templates from one format to another.  Currently only supports converting
  from json to yaml.

  Usage: ${0}
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts : FLAG; then
    case ${FLAG} in
      # List of local options:

      # Pass unrecognized options ...
      \?) pass+=" -${OPTARG}" ;;
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

# -----------------------------------------------------------------------------------------------------------------
# Define hook scripts:
# - These must be defined before the main settings script 'settings.sh' is loaded.
# -----------------------------------------------------------------------------------------------------------------
onRequiredOptionsExist() {
  (
    # No required options ...
    return 0
  )
}

onUsesCommandLineArguments() {
  (
    # This script is expecting command line arguments to be passed ...
    return 0
  )
}

# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
# Load the project settings and functions ...
_includeFile="ocFunctions.inc"
_settingsFile="settings.sh"
if [ ! -z $(type -p ${_includeFile}) ]; then
  _includeFilePath=$(type -p ${_includeFile})
  export OCTOOLSBIN=$(dirname ${_includeFilePath})

  if [ -f ${OCTOOLSBIN}/${_settingsFile} ]; then
    . ${OCTOOLSBIN}/${_settingsFile}
  fi

  if [ -f ${OCTOOLSBIN}/${_includeFile} ]; then
    . ${OCTOOLSBIN}/${_includeFile}
  fi
else
  _red='\033[0;31m'
  _yellow='\033[1;33m'
  _nc='\033[0m' # No Color
  echo -e \\n"${_red}${_includeFile} could not be found on the path.${_nc}"
  echo -e "${_yellow}Please ensure the openshift-developer-tools are installed on and registered on your path.${_nc}"
  echo -e "${_yellow}https://github.com/BCDevOps/openshift-developer-tools${_nc}"
fi
# ==============================================================================

_cmd=$(toLower ${1-convertJsonToYaml})
shift

case "${_cmd}" in
  convertjsontoyaml)
    convertJsonToYaml
    ;;

  *)
    echoWarning "Unrecognized command; ${_cmd}"
    globalUsage
    ;;
esac