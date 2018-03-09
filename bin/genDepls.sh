#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tool to process OpenShift deployment config templates using local and project settings

  Usage: ./genDepls.sh [ -h -e <Environment> -c <component> -k -u -x ]

  OPTIONS:
  ========
    -h prints the usage for the script
    -e <Environment> the environment (dev/test/prod) into which you are deploying (default: ${DEPLOYMENT_ENV_NAME})
    -c <component> to generate parameters for templates of a specific component
    -l apply local settings and parameters
    -p <profile> load a specific settings profile; setting.<profile>.sh
    -P Use the default settings profile; settings.sh.  Use this flag to ignore all but the default 
       settings profile when there is more than one settings profile defined for a project.        
    -k keep the json produced by processing the template
    -u update OpenShift deployment configs instead of creating the configs
    -x run the script in debug mode to see what's happening
    -g process the templates and generate the configuration files, but do not create or update them
       automatically set the -k option

    Update settings.sh and settings.local.sh files to set defaults
EOF
exit
}

# Process the command line arguments
# In case you wanted to check what variables were passed
# echo "flags = $*"
while getopts p:Pc:e:lukxhg FLAG; do
  case $FLAG in
    c ) export COMP=$OPTARG ;;
    p ) export PROFILE=$OPTARG ;;
    P ) export IGNORE_PROFILES=1 ;;    
    e ) export DEPLOYMENT_ENV_NAME=$OPTARG ;;
    l ) export APPLY_LOCAL_SETTINGS=1 ;;
    u ) export OC_ACTION=replace ;;
    k ) export KEEPJSON=1 ;;
    x ) export DEBUG=1 ;;
    g ) export KEEPJSON=1
        export GEN_ONLY=1
      ;;
    h ) usage ;;
    \? ) #unrecognized option - show help
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

for component in ${components}; do
  if [ ! -z "${COMP}" ] && [ ! "${COMP}" = ${component} ]; then
    # Only process named component if -c option specified
    continue
  fi

  echo -e \\n"Configuring the ${DEPLOYMENT_ENV_NAME} environment for ${component} ..."\\n
	pushd ../${component}/openshift >/dev/null
	compDeployments.sh component
	exitOnError
	popd >/dev/null
done

if [ -z ${GEN_ONLY} ]; then
  # ==============================================================================
  # Post Deployment processing
  cat <<-EOF

Use the OpenShift Console to monitor the deployment in the ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME} project.

If a deploy hangs take these steps:
 - cancel the instance of the deployment
 - edit the Deployment Config Resources and remove the entire 'resources' node; this should only be an issue for local deployments."
 - click the Deploy button to restart the deploy

EOF
fi
