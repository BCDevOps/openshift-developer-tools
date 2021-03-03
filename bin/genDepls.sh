#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tool to process OpenShift deployment config templates using local and project settings

  Usage:
    ${0##*/} [options]
EOF
}

postDeploymentProcessing() {
  cat <<-EOF

Use the OpenShift Console to monitor the deployment in the ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME} project.

If a deploy hangs take these steps:
 - cancel the instance of the deployment
 - edit the Deployment Config Resources and remove the entire 'resources' node; this should only be an issue for local deployments."
 - click the Deploy button to restart the deploy

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
cleanConfigs
cleanOverrideParamFiles

for component in ${components}; do
  if [ ! -z "${COMP}" ] && [ ! "${component}" = "." ] && [ ! "${COMP}" = ${component} ]; then
    # Only process named component if -c option specified
    continue
  fi

  echo -e \\n"Configuring the ${DEPLOYMENT_ENV_NAME} environment for ${component} ..."
  compDeployments.sh ${component}
  exitOnError
done

# Delete the configuration files if the keep command line option was not specified.
if [ -z "${KEEPJSON}" ]; then
  echo -e \\n"Removing temporary deployment configuration files ..."
  cleanConfigs
fi

if [ -z ${GEN_ONLY} ]; then
  # If a certificate.conf file is found try to automatically install the cerificates.
  deployCertificates

  # Print post deployment processing information
  postDeploymentProcessing
fi