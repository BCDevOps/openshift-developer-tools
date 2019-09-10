#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() { #Usage function
  cat <<-EOF
  Tool to load data from the APISpec/TestData folder into the app

  Usage:
    ${0##*/} [options]

  Options:
  ========
    -e <server> load data into the specified server (default: ${LOAD_DATA_SERVER}, Options: local/dev/test/prod/<URL>)
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :e: FLAG; then
    case ${FLAG} in
      # List of local options:
      e ) LOAD_DATA_SERVER=$OPTARG ;;

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

# Load Test Data
echo -e "Loading data into TheOrgBook Server: ${LOAD_DATA_SERVER}"
pushd ../APISpec/TestData >/dev/null
./load-all.sh ${LOAD_DATA_SERVER}
popd >/dev/null
