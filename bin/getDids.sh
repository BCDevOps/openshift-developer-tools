#!/bin/bash
export MSYS_NO_PATHCONV=1
SCRIPT_HOME="$( cd "$( dirname "$0" )" && pwd )"

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  Tool to for getting did information from a cluster.  This tool is specific to
  projects using Hyperledger Indy and Aries.

  Usage: ${0} command [options]

  Commands:

    dids [-f <filter>] [-d <cluster>] [--no-ledger-scan] [--hyperlink] [--no-clean]
      - Get a list of dids for all the projects in a cluster.
      Options:
        -f <filter>: The keyword to filter the list on.  For example SOVRIN_STAGINGNET to return only results from Sovrin StagingNet,
                     or a99fd4-prod to return only results from the a99fd4-prod namespace in OCP.
        -d <cluster>: Defines the target cluster
        --no-ledger-scan: Do not scan ledgers for the DID.  This can be used to save some time if the informaiton about the DID from
                          the ledgers is not needed.
        --hyperlink: Generate a hyperlink for the agent name.  Turns the agent name into a clickable link when viewing the csv in excel.
                     Does not format well for console output.
        --no-clean: Skip the cleanup of the von-network environment.  Useful if you are planning mutiple runs.
      Examples:
        ${0} dids
        ${0} dids -f SOVRIN
        ${0} dids -d api-silver-devops-gov-bc-ca:6443 -f SOVRIN
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :-: FLAG; then

    # echo ${FLAG}
    # echo ${OPTARG}

    case ${FLAG} in
      # List of local options:

      # Pass any switches  ...
      - ) switches+=" --${OPTARG}" ;;

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
_getDidsInc="getDids.inc"
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

  if [ -f ${OCTOOLSBIN}/${_getDidsInc} ]; then
    . ${OCTOOLSBIN}/${_getDidsInc}
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

_cmd=$(toLower ${1-dids})
shift

case "${_cmd}" in
  dids)
    getDids ${@} ${switches}
    ;;

  *)
    echoWarning "Unrecognized command; ${_cmd}"
    globalUsage
    ;;
esac