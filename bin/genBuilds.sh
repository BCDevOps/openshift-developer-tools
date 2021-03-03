#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tool to create or update OpenShift build config templates and Jenkins pipeline deployment using
  local and project settings. Also triggers builds that aren't auto-triggered ("builds"
  variable in settings.sh) and tags the images ("images" variable in settings.sh).

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
# ==============================================================================

echo -e \\n"Removing dangling configuration files ..."
cleanBuildConfigs

for component in ${components}; do
  if [ ! -z "${COMP}" ] && [ ! "${component}" = "." ] && [ ! "${COMP}" = ${component} ]; then
    # Only process named component if -c option specified
    continue
  fi

  echo -e \\n"Configuring the ${TOOLS} environment for ${component} ..."
  compBuilds.sh ${component}
  exitOnError
done

# Delete the configuration files if the keep command line option was not specified.
if [ -z "${KEEPJSON}" ]; then
  echo -e \\n"Removing temporary build configuration files ..."
  cleanBuildConfigs
fi

if [ -z "${SKIP_PIPELINE_PROCESSING}" ]; then
  # Process the Jenkins Pipeline configurations ...
  processPipelines.sh
else
  echoWarning "\nSkipping Jenkins pipeline processing ..."
fi

if [ ! -z "${COMP}" ]; then
  # If only processing one component stop here.
  exit
fi

if [ -z ${GEN_ONLY} ]; then
  # ==============================================================================
  # Post Build processing
  echo -e \\n"Builds created. Use the OpenShift Console to monitor the progress in the ${TOOLS} project."
  echo -e \\n"Pause here until the auto triggered builds complete, and then hit a key to continue the script."
  read -n1 -s -r -p "Press a key to continue..." key
  echo -e \\n
  
  for build in ${builds}; do
    echo -e \\n"Manually triggering build of ${build}..."\\n
    oc -n ${TOOLS} start-build ${build}
      exitOnError
    echo -e \\n"Use the OpenShift Console to monitor the build in the ${TOOLS} project."
    echo -e "Pause here until the build completes, and then hit a key to continue the script."
    echo -e \\n
    echo -e "If a build hangs take these steps:"
    echo -e " - cancel the instance of the build"
    echo -e " - edit the Build Config YAML and remove the entire 'resources' node; this should only be an issue for local deployments."
    echo -e " - click the Start Build button to restart the build"
    echo -e \\n
    read -n1 -s -r -p "Press a key to continue..." key
    echo -e \\n
  done

  if [ ! -z "${images}" ]; then
    # Tag the images for deployment to the DEV environment ...
    tagProjectImages.sh -s latest -t dev
  fi 
fi
