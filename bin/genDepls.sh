#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tool to process OpenShift deployment config templates using local and project settings

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
