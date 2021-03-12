#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# Setup artifactory/docker pull creds
USE_PULL_CREDS=${USE_PULL_CREDS:-true}
CRED_SEARCH_NAMES=${CRED_SEARCH_NAMES}
PULL_CREDS=${PULL_CREDS:-artifactory-creds}
DOCKER_REG=${DOCKER_REG:-docker-remote.artifacts.developer.gov.bc.ca}
PROMPT_CREDS=${PROMPT_CREDS:-false}
if [ -z ${CRED_ENVS} ]; then
  CRED_ENVS="tools dev test prod"
fi

# ===================================================================================
usage() { #Usage function
  cat <<-EOF
  Tool to initialize a set of BC Government standard OpenShift projects.

  Usage:
    ${0##*/} [options]
EOF
}
# ------------------------------------------------------------------------------

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi
# ===================================================================================

# Iterate through Dev, Test and Prod projects granting permissions, etc.
for project in ${PROJECT_NAMESPACE}-${DEV} ${PROJECT_NAMESPACE}-${TEST} ${PROJECT_NAMESPACE}-${PROD}; do

  grantDeploymentPrivileges.sh \
    -p ${project} \
    -t ${TOOLS}
  exitOnError

	echo -e \\n"Granting ${JENKINS_SERVICE_ACCOUNT_ROLE} role to ${JENKINS_SERVICE_ACCOUNT_NAME} in ${project}"
  assignRole ${JENKINS_SERVICE_ACCOUNT_ROLE} ${JENKINS_SERVICE_ACCOUNT_NAME} ${project}
  exitOnError

done

# Search for the default artifactory credentials.  The naming convention changed at one point.
if [ -z ${CRED_SEARCH_NAMES} ]; then
  CRED_SEARCH_NAMES="artifacts-default default-${PROJECT_NAMESPACE}"
fi

buildPullSecret "${USE_PULL_CREDS}" "${CRED_SEARCH_NAMES}" "${PULL_CREDS}" "${DOCKER_REG}" "${PROMPT_CREDS}" "${CRED_ENVS[@]}"
