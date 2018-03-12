#!/bin/bash

OCTOOLSBIN=$(dirname $0)

_component_name=${1}
if [ -z "${_component_name}" ]; then
  echo -e \\n"Missing parameter"\\n
  exit 1
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Turn on debugging if asked
if [ ! -z "${DEBUG}" ]; then
  set -x
fi

# Get list of JSON files - could be in multiple directories below
pushd ${TEMPLATE_DIR} >/dev/null
BUILDS=$(find . -name "*.json" -exec grep -l "BuildConfig\|\"ImageStream\"" '{}' \; | sed "s/.json//" | xargs | sed "s/\.\///g")
popd >/dev/null

# Switch to Tools Project
oc project ${TOOLS} >/dev/null
exitOnError

# Local params file path MUST be relative...Hack!
LOCAL_PARAM_DIR=${PROJECT_OS_DIR}

for build in ${BUILDS}; do
  echo -e \\n"Processing build configuration; ${build}..."

  JSONFILE="${TEMPLATE_DIR}/${build}.json"
  JSONTMPFILE=$( basename ${build}_BuildConfig.json )

  if [ ! -z "${PROFILE}" ]; then
    _paramFileName=$( basename ${build}.${PROFILE} )
  else
    _paramFileName=$( basename ${build} )
  fi

  PARAMFILE=$( basename ${_paramFileName}.param )
  if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
    LOCALPARAM=${LOCAL_PARAM_DIR}/$( basename ${_paramFileName}.local.param )
  fi

  if [ -f "${PARAMFILE}" ]; then
    PARAMFILE="--param-file=${PARAMFILE}"
  else
    PARAMFILE=""
  fi

  if [ -f "${LOCALPARAM}" ]; then
    LOCALPARAM="--param-file=${LOCALPARAM}"
  else
    LOCALPARAM=""
  fi

  oc process --filename=${JSONFILE} ${LOCALPARAM} ${PARAMFILE} > ${JSONTMPFILE}
  exitOnError
  if [ -z ${GEN_ONLY} ]; then
    oc ${OC_ACTION} -f ${JSONTMPFILE}
    exitOnError
  fi

  # Delete the tempfile if the keep command line option was not specified
  if [ -z "${KEEPJSON}" ]; then
    rm ${JSONTMPFILE}
  fi
done
