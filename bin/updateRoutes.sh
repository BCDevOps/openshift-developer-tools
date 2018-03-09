#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() { #Usage function
  cat <<-EOF
  Delete and recreate with defaults the routes in an environment.

  Usage: ${0} [ -h -e <environment> -x ]

  OPTIONS:
  ========
    -h prints the usage for the script
    -e <environment> recreate routes in the named environment (dev/test/prod) (default: ${DEPLOYMENT_ENV_NAME})
    -p <profile> load a specific settings profile; setting.<profile>.sh
    -P Use the default settings profile; settings.sh.  Use this flag to ignore all but the default 
       settings profile when there is more than one settings profile defined for a project.    
    -x run the script in debug mode to see what's happening

    Update settings.sh and settings.local.sh files to set defaults

EOF
exit
}

# In case you wanted to check what variables were passed
# echo "flags = $*"
while getopts p:Pe:xh FLAG; do
  case $FLAG in
    e ) DEPLOYMENT_ENV_NAME=$OPTARG ;;
    p ) export PROFILE=$OPTARG ;;
    P ) export IGNORE_PROFILES=1 ;;
    x ) export DEBUG=1 ;;
    h ) usage ;;
    \?) #unrecognized option - show help
      echo -e \\n"Invalid script option"\\n
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

if [ ! -z "${DEBUG}" ]; then
  set -x
fi

# ===================================================================================
# Fix routes
echo -e "Update routes to default in the project: ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME}"
oc project ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME}
for route in ${routes}; do
  oc delete route ${route}
  oc create route edge --service=${route}
  sleep 3 # Allow the creation of the route to complete
done
