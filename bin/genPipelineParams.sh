#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() { #Usage function
  cat <<-EOF
  Tool to generate OpenShift Jenkins pipeline parameter files for each Jenkinsfile in an application's repository.

  Usage: genParams.sh [ -h -f -l -x -c <component> ]

  OPTIONS:
  ========
    -h prints the usage for the script
    -f force generation even if the file already exists
    -l generate local params files - with all parameters commented out
    -p <profile> load a specific settings profile; setting.<profile>.sh
    -P Use the default settings profile; settings.sh.  Use this flag to ignore all but the default 
       settings profile when there is more than one settings profile defined for a project.    
    -x run the script in debug mode to see what's happening

    Update settings.sh and settings.local.sh files to set defaults

EOF
exit
}
# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
while getopts p:Pc:flxh FLAG; do
  case $FLAG in
    c ) # Accept and ignore this parameter
      ;;
    p ) export PROFILE=$OPTARG ;;
    P ) export IGNORE_PROFILES=1 ;;
    f ) FORCE=1 ;;
    l ) export APPLY_LOCAL_SETTINGS=1 ;;
    x ) export DEBUG=1 ;;
    h ) usage ;;
    \?) #unrecognized option - show help
      echo -e \\n"Invalid script option"\\n
      usage
      ;;
  esac
done

# Shift the parameters in case there any more to be used
shift $((OPTIND-1))

if [ -f ${OCTOOLSBIN}/settings.sh ]; then
  . ${OCTOOLSBIN}/settings.sh
fi

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

# Debug mode
if [ ! -z "${DEBUG}" ]; then
  set -x
fi
# -----------------------------------------------------------------------------------------------------------------
# Function(s):
# -----------------------------------------------------------------------------------------------------------------
getLocalPipelineCommentFilter () {
  _commentFilter="s~^~#~;"

  # Uncomment the main local settings ...
  _commentFilter="${_commentFilter}/SOURCE_REPOSITORY_URL/s~^#~~;"      
  _commentFilter="${_commentFilter}/SOURCE_REPOSITORY_REF/s~^#~~;"      
  
  echo "sed ${_commentFilter}"  
}

generatePipelineParameterFilter (){
  _jenkinsFile=${1}
  if [ -z "${_jenkinsFile}" ]; then
    echo -e \\n"generatePipelineParameterFilter; Missing parameter - name of Jenkinsfile"\\n
    exit 1
  fi

  _directory=$(getDirectory ${_jenkinsFile})
  _jenkinsFileName=$(getJenkinsFileName ${_jenkinsFile})
  _contextDirectory=$(getContextDirectory ${_directory})
  _componentName=$(getComponentNameFromDir ${_directory})
  _pipelineName=$(getPipelineName "${_jenkinsFileName}" "${_componentName}")

  _pipelineJenkinsPathFilter="s~\(^JENKINSFILE_PATH=\).*$~\1${_jenkinsFileName}~"
  _pipelineNameFilter="s~\(^NAME=\).*$~\1${_pipelineName}~"
  _pipelineContextDirFilter="s~\(^CONTEXT_DIR=\).*$~\1${_contextDirectory}~"

  echo "sed ${_pipelineNameFilter};${_pipelineContextDirFilter};${_pipelineJenkinsPathFilter}"
}

generatePipelineParameterFile (){
  _jenkinsFile=${1}
  _template=${2}
  _output=${3}
  _force=${4}
  _commentFilter=${5}
  _parameterFilter=${6}
  if [ -z "${_jenkinsFile}" ] || [ -z "${_template}" ]; then
    echo -e \\n"generatePipelineParameterFile; Missing parameter!"\\n
    exit 1
  fi

  if [ -f "${_jenkinsFile}" ]; then
    if [ ! -f "${_output}" ] || [ ! -z "${_force}" ]; then
      if [ -z "${_force}" ]; then
        echo -e "Generating pipeline parameter file for ${_jenkinsFile}; ${_output} ..."\\n
      else
        echoWarning "Overwriting the pipeline parameter file for ${_jenkinsFile}; ${_output} ...\n"
      fi

      # Generate the pipeline parameter file ...
      echo -e "#=========================================================" > ${_output}
      echo -e "# OpenShift Jenkins pipeline template parameters for:" >> ${_output}
      echo -e "# Jenkinsfile: ${_jenkinsFile}" >> ${_output}
      echo -e "# JSON Template File: ${_template}" >> ${_output}
      echo -e "#=========================================================" >> ${_output}
      appendParametersToFile "${_template}" "${_output}" "${_commentFilter}" "${_parameterFilter}"
      exitOnError
    else
      echoWarning "The pipeline parameter file for ${_jenkinsFile} already exists and will not be overwritten; ${_output} ...\n"
      export FORCENOTE=1
    fi
  else
    echoError "Unable to generate pipeline parameter file for ${_jenkinsFile}.  The file does not exist."
  fi
}
# =================================================================================================================

# =================================================================================================================
# Main:
# -----------------------------------------------------------------------------------------------------------------
if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
  COMMENTFILTER=$(getLocalPipelineCommentFilter)
  _outputDir=$(pwd -P)
fi

echo
echo "================================================================================================================="
echo "Processing Jenkinsfiles"
echo "-----------------------------------------------------------------------------------------------------------------"

# Get list of all of the Jenkinsfiles in the project ...
pushd ${PROJECT_DIR} >/dev/null
JENKINS_FILES=$(getJenkinsFiles)

# Generate pipeline parameter files for each one ...
for _jenkinsFile in ${JENKINS_FILES}; do
  _outputPath=$(getPipelineParameterFileOutputPath "${_jenkinsFile}" "${_outputDir}")
  _parameterFilter=$(generatePipelineParameterFilter "${_jenkinsFile}")
  generatePipelineParameterFile "${_jenkinsFile}" "${PIPELINE_JSON}" "${_outputPath}" "${FORCE}" "${COMMENTFILTER}" "${_parameterFilter}"
  exitOnError
done
popd >/dev/null
echo "================================================================================================================="

# Print informational messages ...
if [ ! -z "${APPLY_LOCAL_SETTINGS}" ] && [ -z "${FORCENOTE}" ]; then
  echoWarning "\nLocal files generated with parmeters commented out. Edit the files to uncomment and set parameters as needed.\n"
fi

if [ ! -z "${FORCENOTE}" ]; then
  echoWarning "One or more pipeline parameter files to be generated already exist and were not overwritten.\nUse the -f option to force the overwriting of existing files.\n"
  unset FORCENOTE
fi
# =================================================================================================================
