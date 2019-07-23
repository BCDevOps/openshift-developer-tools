#!/bin/bash

OCTOOLSBIN=$(dirname $0)

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

createGlusterfsClusterApp.sh \
  -p ${TOOLS}
exitOnError

# Iterate through Dev, Test and Prod projects granting permissions, etc.
for project in ${PROJECT_NAMESPACE}-${DEV} ${PROJECT_NAMESPACE}-${TEST} ${PROJECT_NAMESPACE}-${PROD}; do

  grantDeploymentPrivileges.sh \
    -p ${project} \
    -t ${TOOLS}
  exitOnError

	echo -e \\n"Granting ${JENKINS_SERVICE_ACCOUNT_ROLE} role to ${JENKINS_SERVICE_ACCOUNT_NAME} in ${project}"
  assignRole ${JENKINS_SERVICE_ACCOUNT_ROLE} ${JENKINS_SERVICE_ACCOUNT_NAME} ${project}
  exitOnError

  createGlusterfsClusterApp.sh \
    -p ${project}
  exitOnError
done
