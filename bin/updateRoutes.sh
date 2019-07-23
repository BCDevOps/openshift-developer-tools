#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() { #Usage function
  cat <<-EOF
  Delete and recreate with defaults the routes in an environment.

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

# ===================================================================================
# Fix routes
echo -e "Update routes to default in ${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME} ..."
switchProject

for route in ${routes}; do
  oc delete route ${route}
  oc create route edge --service=${route}
  sleep 3 # Allow the creation of the route to complete
done
