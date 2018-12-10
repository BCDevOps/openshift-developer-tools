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
    -h prints the usage for the script
    -e <Environment> the environment (dev/test/prod) into which you are deploying (default: ${DEPLOYMENT_ENV_NAME})
    -l apply local settings and parameters
    -p <profile> load a specific settings profile; setting.<profile>.sh
    -P Use the default settings profile; settings.sh.  Use this flag to ignore all but the default 
       settings profile when there is more than one settings profile defined for a project.        
    -x run the script in debug mode to see what's happening

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

    Update settings.sh and settings.local.sh files to set defaults
EOF
exit
}

# Process the command line arguments
# In case you wanted to check what variables were passed
# echo "flags = $*"
while getopts f:e:r:c:k:p:Plxh FLAG; do
  case $FLAG in
    f ) 
      configFile=$OPTARG 
      ;;
    e ) 
      export DEPLOYMENT_ENV_NAME=$OPTARG
      ;;
    r ) 
      routeName=$OPTARG
      ;;
    c ) 
      certFilename=$OPTARG 
      ;;
    k ) 
      pkFilename=$OPTARG 
      ;;
    p ) 
      export PROFILE=$OPTARG 
      ;;

    P ) 
      export IGNORE_PROFILES=1 
      ;;    
    l ) 
      export APPLY_LOCAL_SETTINGS=1 
      ;;

    x ) 
      export DEBUG=1
      ;;
    h ) 
      usage 
      ;;
    \? )
      #unrecognized option - show help
      echo -e \\n"Invalid script option: -${OPTARG}"\\n
      usage
      ;;
  esac
done

# Shift the parameters in case there any more to be used
shift $((OPTIND-1))
# echo Remaining arguments: $@

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

if [ ! -z "${DEBUG}" ]; then
  set -x
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

for route in ${routes}; do
  echo
  installCertificate "${route}"
done