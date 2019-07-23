#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tool to transfer existing OpenShift routes from one project to another.

  Usage: 
    ${0##*/} [ Options ]

  Examples:
    Using a config file (recommended):
      - ${0##*/} -s devex-bcgov-dac-dev -d devex-von-bc-tob-prod -f routes.conf

    Using discrete parameters:
      - ${0##*/} -s devex-bcgov-dac-dev -d devex-von-bc-tob-prod -r www-orgbook

  Options:
  ========
    -f <ConfigFilePath>; The path to a config file containing a list of one or more routes to transfer.

       Example file:
        # =========================================================
        # List the routes you want to transfer.
        #
        # The entries must be in the following form:
        # - routeName
        # --------------------------------------------------------
        orgbook-pathfinder
        orgbook
        angular-on-nginx-tmp
        www-orgbook

    -r <routeName>; The name of the route to transfer.

    -s <sourceProjectName>; The name of the source project.

    -d <destinationProjectName>; The name of the destination project.
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :s:d:f:r: FLAG; then
    case ${FLAG} in
      # List of local options:
      s ) fromProject=$OPTARG ;;
      d ) toProject=$OPTARG ;;
      f ) configFile=$OPTARG ;;
      r ) routeName=$OPTARG ;;

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

# Profiles are not used for this script
export IGNORE_PROFILES=1

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi
# ==============================================================================

if [ ! -z ${fromProject} ] && [ ! -z ${toProject} ] && [ ! -z ${configFile} ] && [ -f ${configFile} ]; then
  routes=$(readConf ${configFile})
elif [ ! -z ${fromProject} ] && [ ! -z ${toProject} ] && [ ! -z ${routeName} ]; then
  routes=${routeName}
else
  echo -e \\n"Missing one or more required parameters:"\\n
  echo -e "  - fromProject: ${fromProject}"
  echo -e "  - toProject: ${toProject}"
  echo -e "  - routeName: ${routeName}"
  echo -e "  - configFile: ${configFile}"\\n
  usage
fi

transferRoutes "${fromProject}" "${toProject}" "${routes}"