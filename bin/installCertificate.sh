#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tool to process automate the installation of certificates on OpenShift routes.

  Usage: ${0} [ Options ]

  Examples:
    Using a config file (recommended):
      - ${0} -p bc-tob -f certificate.conf
    
    Using discrete parameters:
      - ${0} -p bc-tob -e dev -r test -c server.crt -k private.key

  Options:
  ========
    -f <ConfigFilePath>; The path to a config file containing a list of comma separated entries containing the
       parameters needed to install certificates on one or more routes.

       File content must be in the form:
         projectName,routeName,certFilename,pkFilename

       Example file:
        # =========================================================
        # List the projects, routes, and certificates you want to
        # install.
        #
        # The entries must be in the following form:
        # - projectName,routeName,certFilename,pkFilename
        # --------------------------------------------------------
        devex-von-bc-tob-dev,test,Combined.crt,private.key
        devex-von-bc-tob-prod,test2,/c/tmp/Combined.crt,/c/tmp/private.key

    -r <routeName>; The name of the route on which to install the certificate.

    -c <certificatePath>; The path to the certificate file.

    -k <privateKeyFile>; The path to the private key for the certificate.
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :f:r:c:k: FLAG; then
    case ${FLAG} in
      # List of local options:
      f ) configFile=$OPTARG ;;
      r ) routeName=$OPTARG ;;
      c ) certFilename=$OPTARG ;;
      k ) pkFilename=$OPTARG ;;

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

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi
# ==============================================================================

projectName=$(getProjectName)

if [ ! -z ${configFile} ] && [ -f ${configFile} ]; then
  routes=$(readConf ${configFile})
elif [ ! -z ${projectName} ] && [ ! -z ${routeName} ] && [ ! -z ${certFilename} ] && [ ! -z ${pkFilename} ]; then
  routes=${projectName},${routeName},${certFilename},${pkFilename}
else
  echo -e \\n"Missing one or more required parameters:"\\n
  echo -e "  - configFile: ${configFile}"
  echo -e "  - projectName: ${projectName}"
  echo -e "  - routeName: ${routeName}"
  echo -e "  - certFilename: ${certFilename}"
  echo -e "  - pkFilename: ${pkFilename}"\\n
  usage
fi

installCertificates "${projectName}" "${routes}"