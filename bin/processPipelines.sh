#!/bin/bash

OCTOOLSBIN=$(dirname $0)

if [ -z "${OC_ACTION}" ]; then
  echo -e \\n"Missing parameter."\\n
  exit 1
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Turn on debugging if asked
if [ ! -z "${DEBUG}" ]; then
  set -x
fi
# =================================================================================================================

# Get list of all of the Jenkinsfiles in the project ...
pushd ${PROJECT_DIR} >/dev/null
JENKINS_FILES=$(getJenkinsFiles)

# Local params file path MUST be relative...Hack!
_localParamsDir=openshift

# Process the pipeline for each one ...
for _jenkinsFile in ${JENKINS_FILES}; do
  echo -e \\n"Processing Jenkins Pipeline; ${_jenkinsFile}  ..."

  _template="${PIPELINE_JSON}"
  _defaultParams=$(getPipelineParameterFileOutputPath "${_jenkinsFile}")
  _output="${_jenkinsFile}-pipeline_BuildConfig.json"  
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

  oc process --filename=${_template} ${_localParams} ${_defaultParams} > ${_output}
  exitOnError
  if [ -z ${GEN_ONLY} ]; then
    oc ${OC_ACTION} -f ${_output}
    exitOnError
  fi

  # Delete the temp file if the keep command line option was not specified.
  if [ -z "${KEEPJSON}" ]; then
    rm ${_output}
  fi
done
popd >/dev/null
