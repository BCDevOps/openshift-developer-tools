#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  Tool to generate OpenShift template parameters files in expected places (project or local) for BC Gov applications.

  Usage:
    ${0##*/} [options]

  Options:
  ========
    -f force generation even if the file already exists
EOF
}

# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :f FLAG; then
    case ${FLAG} in
      # List of local options:
      f ) FORCE=1 ;;
      
      # Pass unrecognized options ...
      \?) 
        pass+=" -${OPTARG}"
        ;;
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

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
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

getParameterFileOutputPath () {
  _type=${1}
  _fileName=${2}
  if [ -z "${_type}" ] || [ -z "${_fileName}" ]; then
    echo -e \\n"getParameterFileOutputPath; Missing parameter!"\\n
    exit 1
  fi

  if [ ! -z "${PROFILE}" ] && [ "${PROFILE}" != "${_defaultProfileName}" ]; then
    _outputFilename="${_fileName}.${PROFILE}"
  else
    _outputFilename="${_fileName}"
  fi

  case ${_type} in
    r ) # Regular file
      _output=${_outputFilename}.param
      ;;
    d ) # Dev File
      _output=${_outputFilename}.${DEV}.param
      ;;
    t ) # Test File
      _output=${_outputFilename}.${TEST}.param
      ;;
    p ) # Prod
      _output=${_outputFilename}.${PROD}.param
      ;;
    l ) # Local Files
      _output=${_outputFilename}.local.param
      ;;
    *) # unrecognized option
      echoError  "\ngetParameterFileOutputPath; Invalid type option.\n"
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
      echo -e "# Template File: ${_template}" >> ${_output}
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
  if [ ! -z "${COMP}" ] && [ ! "${component}" = "." ] && [ ! "${COMP}" = ${component} ]; then
    # Only process named component if -c option specified
    continue
  fi

  echo
  echo "================================================================================================================="
  echo "Processing templates for ${component}"
  echo "-----------------------------------------------------------------------------------------------------------------"

  _configTemplates=$(getConfigTemplates $(getTemplateDir ${component}))
  # echo "Configuration templates:"
  # for configTemplate in ${_configTemplates}; do
  #   echo ${configTemplate}
  # done
  # exit 1

  # Iterate through each file and generate the params files
  for file in ${_configTemplates}; do
    # Don't generate dev/test/prod param files for Build templates
    TEMPLATE=${file}
    if isBuildConfig ${TEMPLATE}; then
      _isBuildConfig=1
    else
      unset _isBuildConfig
    fi

    for type in ${PARM_TYPES}; do
      # Don't create environment specific param files for Build Templates
      if ! skipParameterFileGeneration "${type}" "${_isBuildConfig}"; then
        _commentFilter=$(getParameterFileCommentFilter "${type}")
        _output=$(getParameterFileOutputPath "${type}" "${file%.*}")
        _parameterFilter=$(generateParameterFilter "${component}" "${type}" "$(getFilenameWithoutExt ${file})")
        # echoWarning "file: ${file}"
        # echoWarning "file wo/ext: ${file%.*}"
        # echoWarning "_output: ${_output}"
        # echoWarning "_commentFilter: ${_commentFilter}"
        # echoWarning "_parameterFilter: ${_parameterFilter}"
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