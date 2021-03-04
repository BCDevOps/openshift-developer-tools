# git bash hack on windows - deals with pathname conversions from dos to unix-style
export MSYS_NO_PATHCONV=1

# =================================================================================================================
# Functions:
# -----------------------------------------------------------------------------------------------------------------
globalUsage() {
  # Print the scripts useage first ...
  usage

  cat <<-EOF

  Global Commands:

    listProfiles
      - Get a list of profiles for the project.
        Example:
          $0 -e null listProfiles
          $0 -p myprofile -e null listProfiles

    profileDetails
      - Get the details of the project's profile(s).  Lists the templates associated to the profile.
        Example:
          $0 -e null profileDetails                   - List the details for the project's only profile.
          $0 -p myprofile -e null profileDetails      - List the details for the 'myprofile' profile.
          $0 -p default -e null profileDetails all    - List the details for all of the profiles in the project.

  Global Options:
    - Note: Local script options will override these global options.
  ========
    -h prints the usage for the script

    -n <FULLY_QUALIFIED_NAMESPACE>
       Overrides your project and environmnet namespace with a fully qualified namespace.
    -e <Environment>
       The environment (dev/test/prod) into which you are deploying (default: ${DEPLOYMENT_ENV_NAME})
    -c <component>
       To generate parameters for templates of a specific component
    -l apply local settings and parameters
    -p <profile>
       Load a specific settings profile; setting.<profile>.sh
    -P Use the default settings profile; settings.sh.  Use this flag to ignore all but the default
       settings profile when there is more than one settings profile defined for a project.
    -k keep the json produced by processing the template
    -g process the templates and generate the configuration files, but do not create or update them
       automatically set the -k option
    -u update OpenShift deployment configs instead of creating the configs
    -x run the script in debug mode to see what's happening

    Update settings.sh and settings.local.sh files to set defaults
EOF
  exit 1
}

echoWarning (){
  _msg=${@}
  _yellow='\033[1;33m'
  _nc='\033[0m' # No Color
  echo -e "${_yellow}${_msg}${_nc}" >&2
}

getProfiles() {
  _profiles=$(find . -name "settings*.sh" | sed "s~^.*settings.~~;s~.sh~~;s~^sh~${_defaultProfileName}~")
  echo "${_profiles}"
}

countProfiles() {
  echo "${#}"
}

profilesSettingsExist() {
  (
    _profiles=$(getProfiles)
    _profileCount=$(countProfiles $(echo "${_profiles}" | sed "s~^${_defaultProfileName}~~;s~^${_localProfileName}~~"))

    if (( ${_profileCount} >= 1 )); then
      return 0
    else
      return 1
    fi
  )
}

profileExists()
{
  _profile=${1}
  _profiles=$(getProfiles)
  if [[ ${_profiles} == *${_profile}* ]]; then
    return 0
  else
    return 1
  fi
}

printProfiles() {
  _profiles=$(getProfiles)
  _count=$(countProfiles ${_profiles})
  if [[ ${_count} -eq 1 ]]; then
    _profileDescription="profile"
  else
    _profileDescription="profiles"
  fi

  echoWarning "\n=================================================================================================="
  echoWarning "Warning:"
  echoWarning "Your project contains ${_count} ${_profileDescription}."
  echoWarning "Please select the profile you wish to use."
  echoWarning "--------------------------------------------------------------------------------------------------"
  listProfileDetails ${_profiles}
  echoWarning "=================================================================================================="
}

listProfileDetails() {
  local OPTIND
  local unset _verbose
  while getopts v FLAG; do
    case $FLAG in
      v ) local _verbose=1 ;;
    esac
  done
  shift $((OPTIND-1))

  _profiles=${@}

  for _profile in ${_profiles}; do
    settingsFile=$(echo ${_settingsFileName}.${_profile}${_settingsFileExt} | sed "s~.${_defaultProfileName}~~")
    echoWarning "${_profile} - ${settingsFile}"
   
    description=$(cat ${settingsFile} | sed -n 's~^.*description[=:][[:space:]]*\(.*\)$~\1~pI')
    if [ ! -z "${description}" ]; then
      echo "  - ${description}"
    fi

    if [ ! -z "${_verbose}" ]; then   
      # Override the current profile settings ...
      export PROFILE=${_profile}
      export SKIP_PIPELINE_PROCESSING=
      export ignore_templates=
      export include_templates=

      # Always load the default profile settings ...
      . ${PWD}/${_settingsFileName}${_settingsFileExt}

      # Then load the desired profile settings ...
      . ${PWD}/${settingsFile}
      
      # List the templates for the profile ...
      templates=$(getBuildTemplates $(getTemplateDir) 2>/dev/null)
      echo -e "  Build Templates:"
      for template in ${templates}; do
        echo "    - ${template}"
      done

      templates=$(getDeploymentTemplates $(getTemplateDir) 2>/dev/null)
      echo -e "\n  Deployment Templates:"
      for template in ${templates}; do
        echo "    - ${template}"
      done

      templates=$(getConfigTemplates $(getTemplateDir) 2>/dev/null)
      echo -e "\n  Configuration Templates:"
      for template in ${templates}; do
        echo "    - ${template}"
      done
    fi
  done
}

printSettingsFileNotFound() {
  echoWarning "\n=================================================================================================="
  echoWarning "Warning:"
  echoWarning "--------------------------------------------------------------------------------------------------"
  echoWarning "No project settings file (${_settingsFileName}${_settingsFileExt}) was found in '${PWD}'."
  echoWarning "Make sure you're running the script from your project's top level 'openshift' directory"
  echoWarning "and you have a 'settings.sh' file in that folder."
  echoWarning "=================================================================================================="
}

printLocalSettingsFileNotFound() {
  echo -e "\n=================================================================================================="
  echo "Information:"
  echo "--------------------------------------------------------------------------------------------------"
  echo "You've specified you want to apply local profile settings, but no local profile settings"
  echo "(${_settingsFileName}.${_localProfileName}${_settingsFileExt}) were found in '${PWD}'."
  echo "This is a great way to apply overrides when you are generating local parameter files."
  echo "=================================================================================================="
}

printProfileNotFound() {
  _profiles=$(getProfiles)
  _count=$(countProfiles ${_profiles})

  echoWarning "\n=================================================================================================="
  echoWarning "Warning:"
  echoWarning "--------------------------------------------------------------------------------------------------"
  echoWarning "The selected settings profile (${_settingsFileName}.${PROFILE}${_settingsFileExt}) does not exist."
  echoWarning "Please select from one of the available profiles."
  echoWarning "--------------------------------------------------------------------------------------------------"
  for _profile in ${_profiles}; do
    echoWarning "$(echo "${_profile} - ${_settingsFileName}.${_profile}${_settingsFileExt}" | sed "s~.${_defaultProfileName}~~")"
  done
  echoWarning "=================================================================================================="
}

validateSettings() {
  unset _error

  if [ -z "${IGNORE_PROFILES}" ] && [ -z "${PROFILE}" ] && profilesSettingsExist; then
      _error=0
    printProfiles
  fi

  # Load settings in order
  # 1. settings.sh
  if [ ! ${_error} ]; then
    if profileExists "${_defaultProfileName}"; then
      _settingsFiles="${_settingsFiles} ./${_settingsFileName}${_settingsFileExt}"
    else
      _error=0
      printSettingsFileNotFound
    fi
  fi

  # 2. settings.${PROFILE}.sh
  if [ ! ${_error} ] && [ -z "${IGNORE_PROFILES}" ]; then
    if [ ! -z "${PROFILE}" ] && [ "${PROFILE}" != "${_defaultProfileName}" ] && profileExists ${PROFILE}; then
      _settingsFiles="${_settingsFiles} ./${_settingsFileName}.${PROFILE}${_settingsFileExt}"
    elif [ ! -z "${PROFILE}" ] && [ "${PROFILE}" != "${_defaultProfileName}" ]; then
      _error=0
      printProfileNotFound
    fi
  fi

  # 3. settings.local.sh
  if [ ! ${_error} ]; then
    if [ ! -z "${APPLY_LOCAL_SETTINGS}" ] && profileExists "${_localProfileName}"; then
      _settingsFiles="${_settingsFiles} ./${_settingsFileName}.${_localProfileName}${_settingsFileExt}"
    elif [ ! -z "${APPLY_LOCAL_SETTINGS}" ]; then
      _error=0
      printLocalSettingsFileNotFound
    fi
  fi

  export SETTINGS_FILES=${_settingsFiles}

  if [ ! ${_error} ]; then
    return 0
  else
    return 1
  fi
}

settingsLoaded() {
  (
    if [ -z "${SETTINGS_LOADED}" ]; then
      return 1
    else
      return 0
    fi
  )
}

ensureRequiredOptionsExist() {
  (
    # Call the 'onRequiredOptionsExist' hook if defined ...
    if type onRequiredOptionsExist &>/dev/null; then
      if onRequiredOptionsExist; then
        return 0
      else
        return 1
      fi
    else
      return 0
    fi
  )
}

usesCommandLineArguments() {
  (
    # Call the 'onUsesCommandLineArguments' hook if defined ...
    if type onUsesCommandLineArguments &>/dev/null; then
      if onUsesCommandLineArguments; then
        return 0
      else
        return 1
      fi
    else
      return 1
    fi
  )
}
# =================================================================================================================

# =================================================================================================================
# Main Script:
# -----------------------------------------------------------------------------------------------------------------
if ! settingsLoaded; then
  export _componentSettingsFileName=component.settings.sh
  _settingsFileName="settings"
  _settingsFileExt=".sh"
  _localProfileName="local"
  export _defaultProfileName="default"

  # =================================================================================================================
  # Process the command line arguments:
  # - In case you wanted to check what variables were passed; echo "flags = $*"
  # -----------------------------------------------------------------------------------------------------------------
  OPTIND=1
  unset pass
  while [ ${OPTIND} -le $# ]; do
    if getopts :p:Pc:e:lukxhgn: FLAG; then
      case $FLAG in
        h ) globalUsage ;;
        c ) export COMP=$OPTARG ;;
        p ) export PROFILE=$OPTARG ;;
        P ) export IGNORE_PROFILES=1 ;;
        e ) export DEPLOYMENT_ENV_NAME=$OPTARG ;;
        l ) export APPLY_LOCAL_SETTINGS=1 ;;
        u ) export OPERATION=update ;;
        k ) export KEEPJSON=1 ;;
        x ) export DEBUG=1 ;;
        g )
          export KEEPJSON=1
          export GEN_ONLY=1
          ;;
        n )
          export FULLY_QUALIFIED_NAMESPACE=$OPTARG
          echoWarning "Overriding project namespace with fully qualified value, '${FULLY_QUALIFIED_NAMESPACE}' ..."
          ;;

        # Collect unrecognized options ...
        \?) pass+=" -${OPTARG}" ;;
      esac
    else
      globalArgument=$(echo "${!OPTIND}" | tr '[:upper:]' '[:lower:]')
      case "${globalArgument}" in
        profiledetails|listprofiles)
          _globalCmd=${globalArgument}
          ;;
        *)
          # Pass unrecognized arguments ...
          pass+=" ${!OPTIND}"
          ;;
      esac
      let OPTIND++
    fi
  done
  # Pass the unrecognized arguments along for further processing ...
  shift $((OPTIND-1))
  set -- "$@" $(echo -e "${pass}" | sed -e 's/^[[:space:]]*//')
  OPTIND=1
  unset pass

  if [[ ! -z "${@}" ]] && ! usesCommandLineArguments; then
    echoWarning "\nUnexpected command line argument(s) were supplied; [${@}]."
    echoWarning "If your script is expecting these argument(s) you can turn off the warning by implementing the 'onUsesCommandLineArguments' hook in your script before the main settings script is loaded.  The hook should return 0 if you are expecting arguments."
  fi
  # =================================================================================================================

  if [ ! -z "${DEBUG}" ]; then
    set -x
  fi

  if ! ensureRequiredOptionsExist; then
    globalUsage
  fi

  if validateSettings; then
    # Load settings ...
    _settingsFiles=${SETTINGS_FILES}
    echo -e \\n"Loading settings ..."
    for _settingsFile in ${_settingsFiles}; do
      echo -e "Loading settings from ${PWD}/${_settingsFile##*/} ..."
      . ${_settingsFile}
    done
  else
    echoWarning \\n"Your settings are invalid.  Please review the previous messages to correct the errors."
    exit 1
  fi

  # ===========================================================================================================
  # Default settings, many of which you will never need to override.
  # -----------------------------------------------------------------------------------------------------------
  # Project Variables
  export PROJECT_DIR=${PROJECT_DIR:-..}

  export OPERATION=${OPERATION:-create}
  export DEV=${DEV:-dev}
  export TEST=${TEST:-test}
  export PROD=${PROD:-prod}

  export TOOLS=${TOOLS:-${PROJECT_NAMESPACE}-tools}
  export DEPLOYMENT_ENV_NAME=${DEPLOYMENT_ENV_NAME:-${DEPLOYMENT_ENV_NAME:-${DEV}}}
  export BUILD_ENV_NAME=${BUILD_ENV_NAME:-tools}
  export LOAD_DATA_SERVER=${LOAD_DATA_SERVER:-local}
  export TEMPLATE_DIR=${TEMPLATE_DIR:-templates}
  export PIPELINE_JSON=${PIPELINE_JSON:-https://raw.githubusercontent.com/BCDevOps/openshift-tools/master/provisioning/pipeline/resources/pipeline-build.json}
  export COMPONENT_JENKINSFILE=${COMPONENT_JENKINSFILE:-../Jenkinsfile}
  export PIPELINEPARAM=${PIPELINEPARAM:-pipeline.param}
  export APPLICATION_DOMAIN_POSTFIX=${APPLICATION_DOMAIN_POSTFIX:-.apps.silver.devops.gov.bc.ca}

  # Jenkins account settings for initialization
  export JENKINS_ACCOUNT_NAME=${JENKINS_ACCOUNT_NAME:-jenkins}
  export JENKINS_SERVICE_ACCOUNT_NAME=${JENKINS_SERVICE_ACCOUNT_NAME:-system:serviceaccount:${TOOLS}:${JENKINS_ACCOUNT_NAME}}
  export JENKINS_SERVICE_ACCOUNT_ROLE=${JENKINS_SERVICE_ACCOUNT_ROLE:-edit}

  # Gluster settings for initialization
  export GLUSTER_ENDPOINT_CONFIG=${GLUSTER_ENDPOINT_CONFIG:-https://raw.githubusercontent.com/BCDevOps/openshift-tools/master/resources/glusterfs-cluster-app-endpoints.yml}
  export GLUSTER_SVC_CONFIG=${GLUSTER_SVC_CONFIG:-https://raw.githubusercontent.com/BCDevOps/openshift-tools/master/resources/glusterfs-cluster-app-service.yml}
  export GLUSTER_SVC_NAME=${GLUSTER_SVC_NAME:-glusterfs-cluster-app}


  # Build and deployment settings
  export DEPLOYMENT_CONFIG_SUFFIX="_DeploymentConfig.json"
  export BUILD_CONFIG_SUFFIX="_BuildConfig.json"
  export OVERRIDE_PARAM_SUFFIX="overrides.param"

  # ===========================================================================================================

  # ===========================================================================================================
  # Settings you should supply in your project settings file
  # -----------------------------------------------------------------------------------------------------------
  export PROJECT_NAMESPACE=${PROJECT_NAMESPACE:-""}

  # The templates that should not have their GIT referances(uri and ref) over-ridden
  # Templates NOT in this list will have they GIT referances over-ridden
  # with the values of GIT_URI and GIT_REF
  export skip_git_overrides=${skip_git_overrides:-""}
  export GIT_URI=${GIT_URI:-""}
  export GIT_REF=${GIT_REF:-"master"}

  # The project components
  # - defaults to the support the Simple Project Structure
  export components=${components:-"."}

  # The builds to be triggered after buildconfigs created (not auto-triggered)
  export builds=${builds:-""}

  # The images to be tagged after build
  export images=${images:-""}

  # The routes for the project
  export routes=${routes:-""}
  # ===========================================================================================================

  # ===========================================================================================================
  # Test for important parameters.
  # Throw errors/warnings if they are not defined.
  # -----------------------------------------------------------------------------------------------------------
  # ToDo:
  # - Fill in this section.
  # ===========================================================================================================
  export SETTINGS_LOADED=1

  if [ ! -z "${_globalCmd}" ]; then
    # Requires ocFunctions.inc to be loaded ...
    if [ -z "${OC_FUNCTIONS_LOADED}" ]; then
      . ocFunctions.inc
    fi

    pushd ${SCRIPT_HOME} >/dev/null
    case "${_globalCmd}" in
      profiledetails)
        commandArgs=${@}
        if [ ! -z "${commandArgs}" ] && [ "${commandArgs}" == "all" ]; then
          profiles=$(getProfiles)
        else
          profiles=${PROFILE}
        fi

        echo
        listProfileDetails -v "${profiles}"
        ;;

      listprofiles)
        echo
        listProfileDetails $(getProfiles)
        ;;

      *)
        echoWarning "Unrecognized global command; ${_globalCmd}"
        globalUsage
        ;;
    esac
    popd >/dev/null
    exit 0
  fi
else
  echo "Settings already loaded ..."
fi
# =================================================================================================================