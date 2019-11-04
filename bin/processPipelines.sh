#!/bin/bash

OCTOOLSBIN=$(dirname $0)

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Turn on debugging if asked
if [ ! -z "${DEBUG}" ]; then
  set -x
fi
# =================================================================================================================

# Get list of all of the Jenkinsfiles in the project ...
JENKINS_FILES=$(getJenkinsFiles)

# echo "Jenkins files:"
# for _jenkinsFile in ${JENKINS_FILES}; do
#   echo ${_jenkinsFile}
# done
# exit 1

# Local params file path MUST be relative...Hack!
_localParamsDir=openshift

# Process the pipeline for each one ...
for _jenkinsFile in ${JENKINS_FILES}; do
  echo -e \\n"Processing Jenkins Pipeline; ${_jenkinsFile}  ..."

  _template="${PIPELINE_JSON}"
  _defaultParams=$(getPipelineParameterFileOutputPath "${_jenkinsFile}")
  _output="${_jenkinsFile}-pipeline${BUILD_CONFIG_SUFFIX}"

  if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
    _localParams=$(getPipelineParameterFileOutputPath "${_jenkinsFile}" "${_localParamsDir}")
  fi

  if [ -f "${_defaultParams}" ]; then
    _defaultParams="--param-file=${_defaultParams}"
  else
    _defaultParams=""
  fi

  if [ -f "${_localParams}" ]; then
    _localParams="--param-file=${_localParams}"
  else
    _localParams=""
  fi

  oc process --local --filename=${_template} ${_localParams} ${_defaultParams} > ${_output}
  exitOnError
  if [ -z ${GEN_ONLY} ]; then
    oc $(getOcAction) -f ${_output}
    exitOnError
  fi

  # Delete the temp file if the keep command line option was not specified.
  if [ -z "${KEEPJSON}" ]; then
    rm ${_output}
  fi
done