#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  Tool to generate OpenShift template parameters files in expected places (project or local) for BC Gov applications.

  Usage: ./genParams.sh [ -h -f -l -x -c <component> ]

  OPTIONS:
  ========
    -h prints the usage for the script
    -f force generation even if the file already exists
    -l generate local params files - with all parameters commented out
    -c <component> to generate parameters for templates of a specific component
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
    c ) COMP=$OPTARG ;;
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

# What types of files to generate - regular+dev/test/prod or local
if [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
  PARM_TYPES="l"
else
  PARM_TYPES="r d t p"
fi
# -----------------------------------------------------------------------------------------------------------------
# Function(s):
# -----------------------------------------------------------------------------------------------------------------
skipParameterFileGeneration () {
  _type=${1}
  _isBuildConfig=${2}
  if [ -z "${_type}" ]; then
    echo -e \\n"skipParameterFileGeneration; Missing parameter - file generation type"\\n
    exit 1
  fi

  unset _skip
  case ${type} in
    d ) # Dev File
      if [ ! -z "${_isBuildConfig}" ]; then
        _skip=1
      fi
      ;;
    t ) # Test File
      if [ ! -z "${_isBuildConfig}" ]; then
        _skip=1
      fi
      ;;
    p ) # Prod
      if [ ! -z "${_isBuildConfig}" ]; then
        _skip=1
      fi
      ;;
  esac

  if [ -z "${_skip}" ]; then
    return 1
  else
    return 0
  fi
}

getParameterFileCommentFilter () {
  _type=${1}
  if [ -z "${_type}" ]; then
    echo -e \\n"getParameterFileCommentFilter; Missing parameter!"\\n
    exit 1
  fi

  # Default; Comment out everything ...
  _commentFilter="s~^~#~;"
  
  case ${_type} in
    r ) # Regular file
      _commentFilter=cat
      ;;
    [dtp] ) # Dev, Test, and Prod Files
      # Uncomment the main environment specific settings ...
      _commentFilter="${_commentFilter}/TAG_NAME/s~^#~~;"
      _commentFilter="${_commentFilter}/APPLICATION_DOMAIN/s~^#~~;"

      _commentFilter="sed ${_commentFilter}"
      ;;
    l ) # Local file
      # Uncomment the main local settings ...
      _commentFilter="${_commentFilter}/GIT_REPO_URL/s~^#~~;"
      _commentFilter="${_commentFilter}/GIT_REF/s~^#~~;"
      
      _commentFilter="${_commentFilter}/MEMORY_LIMIT/s~^#~~;"
      _commentFilter="${_commentFilter}/MEMORY_REQUEST/s~^#~~;"
      _commentFilter="${_commentFilter}/CPU_LIMIT/s~^#~~;"
      _commentFilter="${_commentFilter}/CPU_REQUEST/s~^#~~;"

      _commentFilter="sed ${_commentFilter}"
      ;;
    *) # unrecognized option
      _commentFilter="sed ${_commentFilter}"
      ;;
  esac

  echo "${_commentFilter}"
}

getParameterFileOutputPrefix () {
  _type=${1}
  if [ -z "${_type}" ]; then
    echo -e \\n"getParameterFileOutputPrefix; Missing parameter!"\\n
    exit 1
  fi

  _outputPrefix=${OUTPUTPREFIX}
  case ${_type} in
    l ) # Local Files
      _outputPrefix=${PROJECT_OS_DIR}
      ;;
  esac

  echo ${_outputPrefix}
}

getParameterFileOutputPath () {
  _type=${1}
  _fileName=${2}
  if [ -z "${_type}" ] || [ -z "${_fileName}" ]; then
    echo -e \\n"getParameterFileOutputPath; Missing parameter!"\\n
    exit 1
  fi

  _outputPrefix=$(getParameterFileOutputPrefix "${_type}")
  if [ ! -z "${PROFILE}" ]; then
    _outputFilename="${_fileName}.${PROFILE}"
  else
    _outputFilename="${_fileName}"
  fi

  case ${_type} in
    r ) # Regular file
      _output=${_outputPrefix}$( basename ${_outputFilename}.param )
      ;;
    d ) # Dev File
      _output=${_outputPrefix}$( basename ${_outputFilename}.${DEV}.param )
      ;;
    t ) # Test File
      _output=${_outputPrefix}$( basename ${_outputFilename}.${TEST}.param )
      ;;
    p ) # Prod
      _output=${_outputPrefix}$( basename ${_outputFilename}.${PROD}.param )
      ;;
    l ) # Local Files
      _output=${_outputPrefix}/$( basename ${_outputFilename}.local.param )
      ;;
    *) # unrecognized option
      echoError  "\ngetParameterFileOutputPath; Invalid type option\n"
      ;;
  esac

  echo ${_output}
}

generateParameterFilter (){
  _component=${1}
  _type=${2}
  _templateName=${3}
  if [ -z "${_component}" ] ||[ -z "${_type}" ] || [ -z "${_templateName}" ]; then
    echo -e \\n"generateParameterFilter; Missing parameter!"\\n
    exit 1
  fi

  _parameterFilters=""
  _environment=${DEV}
  case ${_type} in
    # r ) # Regular file
      # _output=${_outputPrefix}$( basename ${_fileName}.param )
      # ;;
    d ) # Dev File
      _environment=${DEV}
      ;;
    t ) # Test File
      _environment=${TEST}
      ;;
    p ) # Prod
      _environment=${PROD}
      ;;
    l ) # Local Files
      _parameterFilters="${_parameterFilters}s~\(^MEMORY_LIMIT=\).*$~\10Mi~;"
      _parameterFilters="${_parameterFilters}s~\(^MEMORY_REQUEST=\).*$~\10Mi~;"
      _parameterFilters="${_parameterFilters}s~\(^CPU_LIMIT=\).*$~\10~;"
      _parameterFilters="${_parameterFilters}s~\(^CPU_REQUEST=\).*$~\10~;"      
      ;;
  esac

  _name=$(basename "${_templateName}")
  _name=$(echo ${_name} | sed 's~\(^.*\)-\(build\|deploy\)$~\1~')
  _parameterFilters="${_parameterFilters}s~\(^NAME=\).*$~\1${_name}~;"
  _parameterFilters="${_parameterFilters}s~\(^\(IMAGE_NAMESPACE\|SOURCE_IMAGE_NAMESPACE\)=\).*$~\1${TOOLS}~;"

  if [ ! -z "${_environment}" ]; then
    _parameterFilters="${_parameterFilters}s~\(^TAG_NAME=\).*$~\1${_environment}~;"

    _appDomain="${_name}-${PROJECT_NAMESPACE}-${_environment}${APPLICATION_DOMAIN_POSTFIX}"
    _parameterFilters="${_parameterFilters}s~\(^APPLICATION_DOMAIN=\).*$~\1${_appDomain}~;"
  fi

  echo "sed ${_parameterFilters}"
}

generateParameterFile (){
  _component=${1}
  _template=${2}
  _output=${3}
  _force=${4}
  _commentFilter=${5}
  _parameterFilter=${6}
  if [ -z "${_component}" ] || [ -z "${_template}" ]; then
    echo -e \\n"generatePipelineParameterFile; Missing parameter!"\\n
    exit 1
  fi

  if [ -f "${_template}" ]; then
    if [ ! -f "${_output}" ] || [ ! -z "${_force}" ]; then
      if [ -z "${_force}" ]; then
        echo -e "Generating parameter file for ${_template}; ${_output} ..."\\n
      else
        echoWarning "Overwriting the parameter file for ${_template}; ${_output} ...\n"
      fi

      # Generate the parameter file ...
      echo -e "#=========================================================" > ${_output}
      echo -e "# OpenShift template parameters for:" >> ${_output}
      echo -e "# Component: ${_component}" >> ${_output}
      echo -e "# JSON Template File: ${_template}" >> ${_output}
      echo -e "#=========================================================" >> ${_output}
      appendParametersToFile "${_template}" "${_output}" "${_commentFilter}" "${_parameterFilter}"
      exitOnError
    else
      echoWarning "The parameter file for ${_template} already exisits and will not be overwritten; ${_output} ...\n"
      export FORCENOTE=1
    fi
  else
    echoError "Unable to generate parameter file for ${_template}.  The file does not exist."
  fi
}
# =================================================================================================================


# =================================================================================================================
# Main:
# -----------------------------------------------------------------------------------------------------------------
for component in ${components}; do
  if [ ! -z "${COMP}" ] && [ ! "${COMP}" = ${component} ]; then
    # Only process named component if -c option specified
    continue
  fi

  echo
  echo "================================================================================================================="
  echo "Processing templates for ${component}"
  echo "-----------------------------------------------------------------------------------------------------------------"
  pushd ../${component}/openshift >/dev/null

  # Get list of JSON files - they could be in multiple directories below
  pushd ${TEMPLATE_DIR} >/dev/null
  _configTemplates=$(getConfigTemplates)
  popd >/dev/null

  # Iterate through each file and generate the params files
  for file in ${_configTemplates}; do
    # Don't generate dev/test/prod param files for Build templates
    TEMPLATE=${TEMPLATE_DIR}/${file}.json
    if isBuildConfig ${TEMPLATE}; then
      _isBuildConfig=1
    else
      unset _isBuildConfig
    fi

    for type in ${PARM_TYPES}; do
      # Don't create environment specific param files for Build Templates
      if ! skipParameterFileGeneration "${type}" "${_isBuildConfig}"; then
        _commentFilter=$(getParameterFileCommentFilter "${type}")
        _output=$(getParameterFileOutputPath "${type}" "${file}")
        _parameterFilter=$(generateParameterFilter "${component}" "${type}" "${file}")
        generateParameterFile "${component}" "${TEMPLATE}" "${_output}" "${FORCE}" "${_commentFilter}" "${_parameterFilter}"
        exitOnError
      else
        # Remove `>/dev/null` to enable this message.
        # It's useful for troubleshooting, but annoying otherwise.
        echo \
          "Skipping environment specific, environmentType '${type}', parameter file generation for build template; ${file} ..." \
          >/dev/null
      fi
    done
  done

  popd >/dev/null
  echo "================================================================================================================="
done

# Print informational messages ...
if [ ! -z "${APPLY_LOCAL_SETTINGS}" ] && [ -z "${FORCENOTE}" ]; then
  echoWarning "\nLocal files generated with parmeters commented out. Edit the files to uncomment and set parameters as needed.\n"
fi

if [ ! -z "${FORCENOTE}" ]; then
  echoWarning "\nOne or more parameter files to be generated already exist and were not overwritten.\nUse the -f option to force the overwriting of existing files.\n"
  unset FORCENOTE
fi
# =================================================================================================================