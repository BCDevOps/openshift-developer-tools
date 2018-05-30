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
if [ -d "${TEMPLATE_DIR}" ]; then
  BUILDS=$(getBuildTemplates ${TEMPLATE_DIR})
fi

# Switch to Tools Project
switchProject ${TOOLS}
exitOnError

# Local params file path MUST be relative...Hack!
LOCAL_PARAM_DIR=${PROJECT_OS_DIR}

for build in ${BUILDS}; do
  echo -e \\n"Processing build configuration; ${build}..."

  _template="${build}"
  _template_basename=$(getFilenameWithoutExt ${build})
  _buildConfig="${_template_basename}_BuildConfig.json"

  if [ ! -z "${PROFILE}" ]; then
    _paramFileName="${_template_basename}.${PROFILE}"
  else
    _paramFileName="${_template_basename}"
  fi

  PARAMFILE="${_paramFileName}.param"
  if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
    LOCALPARAM="${LOCAL_PARAM_DIR}/${_paramFileName}.local.param"
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

  oc process --filename=${_template} ${LOCALPARAM} ${PARAMFILE} > ${_buildConfig}
  exitOnError
  if [ -z ${GEN_ONLY} ]; then
    oc ${OC_ACTION} -f ${_buildConfig}
    exitOnError
  fi

  # Delete the tempfile if the keep command line option was not specified
  if [ -z "${KEEPJSON}" ]; then
    rm ${_buildConfig}
  fi
done
