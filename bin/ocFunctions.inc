#!/bin/bash

getRelativeOutputDir () {
  # Assumes you are starting in the projects root openshift directory ...
  _openshiftDir=$(pwd -P)

  # Switch to the project directory, which should be up one directory level ...
  pushd ${PROJECT_DIR} >/dev/null
  _projectDir=$(pwd -P)
  popd >/dev/null

  _relativeOutputDir=$(echo ${_openshiftDir} | sed "s~${_projectDir}~.~")
  echo ${_relativeOutputDir}
}

echoWarning (){
  _msg=${@}
  _yellow='\033[1;33m'
  _nc='\033[0m' # No Color
  echo -e "${_yellow}${_msg}${_nc}" >&2
}

echoError (){
  _msg=${@}
  _red='\033[0;31m'
  _nc='\033[0m' # No Color
  echo -e "${_red}${_msg}${_nc}" >&2
}

printAndWait() {
  _msg=${@}
  if [ -z "${_msg}" ]; then
    echo -e \\n"printAndWait; Missing parameter!"\\n
    exit 1
  fi

  echoWarning "\n${_msg}"
  read -n1 -s -r -p $'Press any key to continue ...' key
  echo -e \\n

  # If we get here the user did NOT press Ctrl-C ...
  return 0
}

printAndAskToContinue() {
  _msg=${@}
  if [ -z "${_msg}" ]; then
    echo -e \\n"printAndAskToContinue; Missing parameter!"\\n
    exit 1
  fi

  echoWarning "\n${_msg}"
  read -n1 -s -r -p $'\e[33mWould you like to continue?\e[0m  Press Ctrl-C to exit, or any other key to continue ...' key
  echo -e \\n

  # If we get here the user did NOT press Ctrl-C ...
  return 0
  }

exitOnError() {
  rtnCd=$?
  if [ ${rtnCd} -ne 0 ]; then
    echoError "An error has occurred.  Please check the previous output message(s) for details."
    read -n1 -s -r -p $'\e[33mWould you like to continue?\e[0m  Press Ctrl-C to exit, or any other key to continue ...' key
    echo -e \\n

    # If we get here the user did NOT press Ctrl-C ...
    return 0
  fi
}

getOperation() {
  (
    echo $(toLower ${OPERATION})
  )
}

createOperation() {
  (
    action=$(getOperation)
    if [ ${action} = "create" ]; then
      return 0
    else
      return 1
    fi
  )
}

updateOperation() {
  (
    action=$(getOperation)
    if [ ${action} = "update" ]; then
      return 0
    else
      return 1
    fi
  )
}

getOcAction() {
  (
    unset _action

    if createOperation; then
      # --save-config - Maintains compatibility with 'oc apply'
      _action="create --save-config"
    elif updateOperation; then
      _action="apply"
    else
      echoError "\nUnrecognized oc action, $(getOperation).\n"
      exit 1
    fi

    echo "${_action}"
  )
}

isLocalCluster (){
  rtnVal=$(oc whoami -c |  grep '/127-0\|/10-0\|/192-168\|minishift')
  if [ -z "$rtnVal" ]; then
    # Not a local cluster ..."
    return 1
  else
    # Is a local cluster ..."
    return 0
  fi
}

projectExists (){
  project=$1
  cmd="oc projects | grep '"${project}"'"
  rtnVal=$(eval ${cmd})
  if [ -z "${rtnVal}" ]; then
    # Project does not exist ..."
      return 1
  else
    # Project exists ..."
      return 0
  fi
}

podExists (){
  (
    _podName=${1}
    _podIndex=${2:-0}
    if [ -z "${_podName}" ]; then
      echo -e \\n"podExists; Missing parameter!"\\n
      exit 1
    fi

    # Get name of a currently deployed pod by label and index
    _podInstanceName=$(getPodByName ${_podName} ${_podIndex})
    if [ ! -z "${_podInstanceName}" ]; then
      # The pod exists ...
      return 0
    else
      # The pod does not exist ...
      return 1
    fi
  )
}

dcExists (){
  (
    _dcName=${1}
    _namespace=$(getProjectName)

    if [ -z "${_dcName}" ]; then
      echo -e \\n"dcExists; Missing parameter!"\\n
      exit 1
    fi

    _dcInstanceName=$(oc -n ${_namespace} get dc ${_dcName} --ignore-not-found --template "{{ .metadata.name }}")
    if [ ! -z "${_dcInstanceName}" ]; then
      # The  deployment configuration exists ...
      return 0
    else
      # The deployment configuration does not exist ...
      return 1
    fi
  )
}

isExists (){
  (
    _isName=${1}
    _namespace=${2:-${TOOLS}}

    if [ -z "${_isName}" ]; then
      echo -e \\n"isExists; Missing parameter!"\\n
      exit 1
    fi

    _isInstanceName=$(oc -n ${_namespace} get is ${_isName} --ignore-not-found --template "{{ .metadata.name }}")
    if [ ! -z "${_isInstanceName}" ]; then
      # The  build configuration exists ...
      return 0
    else
      # The build configuration does not exist ...
      return 1
    fi
  )
}

bcExists (){
  (
    _bcName=${1}
    _namespace=${2:-${TOOLS}}

    if [ -z "${_bcName}" ]; then
      echo -e \\n"bcExists; Missing parameter!"\\n
      exit 1
    fi

    _bcInstanceName=$(oc -n ${_namespace} get bc ${_bcName} --ignore-not-found --template "{{ .metadata.name }}")
    if [ ! -z "${_bcInstanceName}" ]; then
      # The  build configuration exists ...
      return 0
    else
      # The build configuration does not exist ...
      return 1
    fi
  )
}

assignRole (){
  (
    role=$1
    user=$2
    project=$3

    if [ -z "${role}" ] || [ -z "${user}" ] || [ -z "${project}" ]; then
      echo -e \\n"assignRole; Missing parameter!"\\n
      exit 1
    fi

    echo "Assigning role [${role}], to user [${user}], in project [${project}] ..."
    oc policy add-role-to-user ${role} ${user} -n ${project}
    echo
  )
}

getDirectory () {
  _path=${1}
  if [ -z "${_path}" ]; then
    echo -e \\n"getDirectory; Missing parameter!"\\n
    exit 1
  fi

  echo ${_path%/*}
}

appendParametersToFile (){
  _template=${1}
  _outputPath=${2}
  _commentFilter=${3}
  _parameterFilter=${4}
  if [ -z "${_template}" ] || [ -z "${_outputPath}" ]; then
    echo -e \\n"appendParametersToFile; Missing parameter!"\\n
    exit 1
  fi

  if [ -z "${_commentFilter}" ]; then
    _commentFilter=cat
  fi

  if [ -z "${_parameterFilter}" ]; then
    _parameterFilter=cat
  fi

  # GIT Overrides ...
  _gitUrlFilter=cat
  _gitUrlFilter=cat
  _gitRefFilter=cat
  _templateName=$(basename ${_template})

  OIFS=$IFS
  IFS=" "
  _skip_git_overrides_array=(${skip_git_overrides})
  if ! contains "${_templateName}" "${_skip_git_overrides_array[@]}"; then
    # Override the GIT URI if it is defined ...
    if [ ! -z "${GIT_URI}" ]; then
      _gitUrlFilter="sed s~\(^\(GIT_REPO_URL\|SOURCE_REPOSITORY_URL\)=\).*$~\1${GIT_URI}~"
    fi


    # Override the GIT Ref if it is defined ...
    if [ ! -z "${GIT_REF}" ]; then
      _gitRefFilter="sed s~\(^\(GIT_REF\|SOURCE_REPOSITORY_REF\)=\).*$~\1${GIT_REF}~"
    fi
  fi
  IFS=$OIFS

  # Fancy sed/awk handling below to convert parameters command-line output to param file format
  # - Delete the first line of the oc process output
  # - Use awk to split output into "columns"; then print out the FIRST and LAST column with '=' in between
  # - Use _commentFilter to add (or not) a "#" in front of each line; "#" comments it out the line
  #  - i.e. set _commentFilter="sed s/^/#/" to comment out the line

  # 1. Remove the headers (the first line) from the output.
  # 2. Split the output into columns, where columns are separated by TWO or more spaces
  #    Having the separator be two consecutive spaces (or more) helps us properly capture values with a SINGLE space in the value column.
  # 3. Starting with the first column, print out the FIRST and LAST column with the following format: FIRST_COLUMN=LAST_COLUMN
  #    This maps to the param file format: Param_Key=Param_Value
  # 4. + Apply additional filters to the parameters
  # 5. Finally, append the resulting output to the parameter file defined in "${_outputPath}"
  oc process --local --parameters --filename=${_template} | \
    sed '1d' | \
    awk -F'[ ]{2,}' '{ print $1 "=" $NF }' | \
    sed 's~\(^GITHUB_WEBHOOK_SECRET=.*$\)~#\1~' | \
    sed 's~\(^GENERIC_WEBHOOK_SECRET=.*$\)~#\1~' | \
    sed 's~\(^DJANGO_SECRET_KEY=.*$\)~#\1~' | \
    ${_gitUrlFilter} | \
    ${_gitRefFilter} | \
    ${_parameterFilter} | \
    ${_commentFilter} | \
    sed 's/^#/# /' \
    >> ${_outputPath}
  exitOnError
}

getSecretTemplates () {
  echo $(find . -name "*secret.json" -exec grep -l "Secret" '{}' \;)
}

getFilenameWithoutExt()
{
  _path=${1}
  if [ -z "${_path}" ]; then
    echo -e \\n"getFilenameWithoutExt; Missing parameter!"\\n
    exit 1
  fi

  _filename=$(basename ${_path})
  _name=${_filename%.*}
  echo ${_name}
}

getSecretFiles () {
  _secretTemplate=${1}
  if [ -z "${_secretTemplate}" ]; then
    echo -e \\n"getSecretFiles; Missing parameter!"\\n
    exit 1
  fi

  # The related files should be in a 'secret' folder under the openshift directory with the same name as the temaple.
  # For example:
  # Template = ./openshift/templates/server/server-secret.json
  # Secrets = ./openshift/secrets/server-secret/*

  # Find all of the secrets associated with the template ...
  _name=$(getFilenameWithoutExt ${_secretTemplate})
  _searchPattern="*/secrets/${_name}/*"
  echo $(find . -path "${_searchPattern}")
}

getJenkinsFiles () {
  (
    _componentName=${1:-${COMP}}
    _searchPath=${2:-${PROJECT_DIR}}

    if [ -z ${_componentName} ]; then
      _searchPattern="^.*Jenkinsfile$"
    else
      _searchPattern="^.*/${_componentName}/*.*Jenkinsfile$"
    fi

    echo $(find ${_searchPath} -type f -regex "${_searchPattern}")
  )
}

getTemplateDir () {
  (
    _componentName=${1}
    if [ ! -z ${_componentName} ] && [ ${_componentName} == '.' ]; then
      unset _componentName
    fi

    _componentName=${_componentName:-${COMP}}
    _searchPath=${2:-${PROJECT_DIR}}
    unset _comResults
    unset _simpleResults

    if [ -z ${_componentName} ]; then
      _compPattern="^.*/openshift/${TEMPLATE_DIR}"
      _simplePattern="^.*/openshift/${TEMPLATE_DIR}"
    else
      _compPattern="^.*/${_componentName}/*.*/*openshift/${TEMPLATE_DIR}"
      _simplePattern="^.*/openshift/${TEMPLATE_DIR}/*.*/${_componentName}"
    fi

    _comResults=$(find ${_searchPath} -type d -regex "${_compPattern}")
    if [ ! "${_compPattern}" = "${_simplePattern}" ]; then
      _simpleResults=$(find ${_searchPath} -type d -regex "${_simplePattern}")
    fi

    _results=${_comResults}
    if [ ! -z "${_simpleResults}" ] &&  [ ! "${_comResults}" = "${_simpleResults}" ]; then
      _results+=" ${_simpleResults}"
    fi

    echo ${_results}
  )
}

filterTemplateList () {
  (
    templates=${@}

    OIFS=$IFS
    IFS=" "

    # Filter on include list
    if [ ! -z "${include_templates}" ]; then
      include_templates_array=(${include_templates})
      for template in ${templates}; do
        templateName=$(getFilenameWithoutExt ${template})
        if contains "${templateName}" "${include_templates_array[@]}"; then
          filteredTemplates+=" ${template}"
        else
          echoWarning "Filtering, '${template}', from the list of templates, it is not in the list of templates to include ..."
        fi
      done
    fi

    # Filter on ignore list
    if [ ! -z "${ignore_templates}" ]; then
      ignore_templates_array=(${ignore_templates})
      for template in ${templates}; do
        templateName=$(getFilenameWithoutExt ${template})
        if ! contains "${templateName}" "${ignore_templates_array[@]}"; then
          filteredTemplates+=" ${template}"
        else
          echoWarning "Filtering, '${template}', from the list of templates, it is in the list of templates to be ignored ..."
        fi
      done
    fi

    IFS=$OIFS
    echo ${filteredTemplates}
  )
}

getTemplates () {
  (
    _filter=${1}
    shift
    _searchPaths=${@}
    if [ -z "${_searchPaths}" ] || [ -z "${_searchPaths}" ]; then
      echoError \\n"getTemplates; Missing parameter!"\\n
      exit 1
    fi

    unset templates
    for searchPath in ${_searchPaths}; do
      templates+=" $(find ${searchPath} -regex "^.*\.\(json\|yaml\|yml\)" -exec grep -l "${_filter}" '{}' \;)"
    done

    if [ ! -z "${ignore_templates}" ] || [ ! -z "${include_templates}" ]; then
      templates=$(filterTemplateList ${templates})
    fi

    echo ${templates}
  )
}

nspTemplateFilter="\bNetworkSecurityPolicy\b\|\bExternalNetwork\b\|\bNetworkPolicy\b"
getNspTemplates () {
  (
    _filter=${1}
    shift
    _searchPaths=${@}
    nspTemplates=$(getTemplates "${nspTemplateFilter}" ${_searchPaths})
    buildAndDeployTemplates+=" $(getTemplates "${buildTemplateFilter}" ${_searchPaths})"
    buildAndDeployTemplates+=" $(getTemplates "${deploymentTemplateFilter}" ${_searchPaths})"
    echo $(filterList "${nspTemplates}" "${buildAndDeployTemplates}") | tr " " "\n" | grep ${_filter}
  )
}

filterList () {
  (
    listItems=${1}
    filterItems=${2}

    OIFS=$IFS
    IFS=" "

    unset filteredList
    filterItemsArray=(${filterItems})
    for listItem in ${listItems}; do
      if ! contains "${listItem}" "${filterItemsArray[@]}"; then
        filteredList+=" ${listItem}"
      fi
    done

    IFS=$OIFS
    echo ${filteredList}
  )
}

nspBuildTemplateFilter="build.*"
getBuildNspTemplates () {
  (
    _searchPaths=${@}
    echo $(getNspTemplates "${nspBuildTemplateFilter}" ${_searchPaths})
  )
}

getDeploymentNspTemplates () {
  (
    _searchPaths=${@}
    echo $(getNspTemplates "deploy.*" ${_searchPaths})
  )
}

buildTemplateFilter="\bBuildConfig\b\|\bpullSecret\b\|\bImageStream\b\|kind:.ImageStream$"
getBuildTemplates () {
  (
    _searchPaths=${@}
    unset buildTemplates
    buildTemplates+=" $(getTemplates "${buildTemplateFilter}" ${_searchPaths})"
    buildTemplates+=" $(getBuildNspTemplates ${_searchPaths})"
    echo ${buildTemplates}
  )
}

deploymentTemplateFilter="\bDeployment\b\|\bDeploymentConfig\b\|\bStatefulSet\b\|\bRoute\b\|\bSecret\b"
getDeploymentTemplates () {
  (
    _searchPaths=${@}
    unset deploymentTemplates
    deploymentTemplates+=" $(getTemplates "${deploymentTemplateFilter}" ${_searchPaths})"
    deploymentTemplates+=" $(getDeploymentNspTemplates ${_searchPaths})"
    echo ${deploymentTemplates}
  )
}

getConfigTemplates () {
  (
    _searchPaths=${@}
    unset configTemplates
    configTemplates+=" $( getBuildTemplates ${_searchPaths})"
    configTemplates+=" $( getDeploymentTemplates ${_searchPaths})"
    echo ${configTemplates}
  )
}

getComponentNameFromDir () {
  _componentDir=${1}
  if [ -z "${_componentDir}" ]; then
    echo -e \\n"getComponentNameFromDir; Missing parameter!"\\n
    exit 1
  fi

  _componentDir_FullName=$(echo ${_componentDir##*/} | sed 's~^\.~~')
  _componentDir_Name=$(echo ${_componentDir%.*} | sed 's~^\.~~')
  if [ -z "${_componentDir_Name}" ]; then
    echo ${_componentDir_FullName}
  else
    echo ${_componentDir_Name}
  fi
}

getContextDirectory () {
  _componentDir=${1}
  if [ -z "${_componentDir}" ]; then
    echo -e \\n"getContextDirectoryFromDir; Missing parameter!"\\n
    exit 1
  fi

  _contextDirectory=$(echo ${_componentDir} | sed 's~^\.~~;s~^\/~~')
  echo ${_contextDirectory}
}

getJenkinsFileName () {
  _jenkinsFilePath=${1}
  if [ -z "${_jenkinsFilePath}" ]; then
    echo -e \\n"getJenkinsFileName; Missing parameter!"\\n
    exit 1
  fi

  echo $(getFilenameWithoutExt ${_jenkinsFilePath})
}

isBuildConfig() {
  _template=${1}
  if [ -z "${_template}" ]; then
    echo -e \\n"isBuildConfig; Missing parameter!"\\n
    exit 1
  fi

  _isBuildConfig=$( grep -l "BuildConfig\|\"ImageStream\"\|kind:.ImageStream$" ${_template} )
  if [ -z "${_isBuildConfig}" ]; then
    # Check if it's a NSP for the build (tools) environment ...
    _isBuildConfig=$(echo "${_template}" | grep ${nspBuildTemplateFilter})
  fi

  if [ -z "${_isBuildConfig}" ]; then
    return 1
  else
    return 0
  fi
}

isDeploymentConfig() {
  _template=${1}
  if [ -z "${_template}" ]; then
    echo -e \\n"isDeploymentConfig; Missing parameter!"\\n
    exit 1
  fi

  _isDeploymentConfig=$( grep -l DeploymentConfig ${_template} )
  if [ -z "${_isDeploymentConfig}" ]; then
    return 1
  else
    return 0
  fi
}

getPipelineParameterFileOutputPath () {
  _jenkinsFile=${1}
  _localOutputDir=${2}
  if [ -z "${_jenkinsFile}" ]; then
    echo -e \\n"getPipelineParameterFileOutputPath; Missing parameter!"\\n
    exit 1
  fi

  if [ -f "${_jenkinsFile}" ]; then
    _directory=$(getDirectory ${_jenkinsFile})
    _jenkinsFileName=$(getJenkinsFileName ${_jenkinsFile})
    if [ ! -z "${PROFILE}" ] && [ "${PROFILE}" != "${_defaultProfileName}" ]; then
      _name="${_jenkinsFileName}.${PROFILE}"
    else
      _name="${_jenkinsFileName}"
    fi

    if [ ! -z "${_localOutputDir}" ]; then
      _componentName=$(getComponentNameFromDir ${_directory})
      if [ ! -z "${_componentName}" ]; then
      _output="${_localOutputDir}/${_componentName}.${_name}.local.${PIPELINEPARAM}"
      else
      _output="${_localOutputDir}/${_name}.local.${PIPELINEPARAM}"
      fi
    else
      _output="${_directory}/${_name}.${PIPELINEPARAM}"
    fi
  fi

  echo ${_output}
}

contains (){
  local _item
  _find=${1}
  shift
  for _item; do [[ "${_item}" == "${_find}" ]] && return 0; done
  return 1
}

getPipelineName (){
  _jenkinsFileName=${1}
  _defaultName=${2}
  if [ -z "${_jenkinsFileName}" ]; then
    echo -e \\n"getPipelineName; Missing parameter!"\\n
    exit 1
  fi

  # Extract the name from the name of the JenkinsFile if possible
  _jenkinsFileName=$(echo ${_jenkinsFileName} | tr '[:upper:]' '[:lower:]')
  _pipelineName=$(echo ${_jenkinsFileName} | sed 's~jenkinsfile~~')
  if [ ! -z "${_pipelineName}" ]; then
    _pipelineName=$(echo ${_jenkinsFileName} | sed 's~.jenkinsfile~~')
  else
    _pipelineName=${_defaultName}
  fi

  # Pipeline names MUST be lowercase
  echo $(echo ${_pipelineName} | tr '[:upper:]' '[:lower:]')
}

recyclePods() {
  (
      local OPTIND
      unset local wait
      unset local flags
      while getopts w FLAG; do
        case $FLAG in
          w )
            local wait=1
            local flags="-w"
            ;;
        esac
      done
      shift $((OPTIND-1))

    _pods=${@}
    if [ -z "${_pods}" ]; then
      _pods=$(getAllPods)
      echoWarning "\nRecycling Scaling all pods;" ${_pods}\\n
    fi

    scaleDown ${flags} ${_pods}
    if [ -z ${wait} ]; then
      printAndWait "Wait for all of the pods (${_pods}) to scale down completely before continuing."
    fi
    scaleUp ${flags} ${_pods}
  )
}

scaleUp() {
  (
    local OPTIND
    unset local wait
    while getopts w FLAG; do
      case $FLAG in
        w ) local wait=1 ;;
      esac
    done
    shift $((OPTIND-1))

    _pods=${@}
    if [ -z "${_pods}" ]; then
      _pods=$(getAllPods)
      echoWarning "\nScaling all pods;" ${_pods}\\n
    fi

    for _pod in ${_pods}; do
      scaleDeployment ${_pod} 1
      if [ ! -z ${wait} ]; then
        waitOnScaleUp ${_pod}
      fi
    done
  )
}

waitOnScaleUp() {
  (
    _deplymentConfigName=${1}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ]; then
      echo -e \\n"waitOnScaleUp; Missing parameter!  You must specify the name of the deployment."\\n
      exit 1
    fi

    printf "Waiting for %s to scale up " ${_deplymentConfigName}
    while ! isScaledUp ${_deplymentConfigName}; do
      printf "."
      sleep 1
    done
    echo -e \\n
  )
}

isScaledUp() {
  (
    _deplymentConfigName=${1}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ]; then
      echo -e \\n"isScaledUp; Missing parameter!  You must specify the name of the deployment."\\n
      exit 1
    fi

    _podCount=$(oc -n ${_namespace} get dc ${_deplymentConfigName} --template "{{ .status.availableReplicas }}")
    if ((${_podCount} >= 1)); then
      return 0
    else
      return 1
    fi
  )
}

scaleDown() {
  (

    local OPTIND
    unset local wait
    while getopts w FLAG; do
      case $FLAG in
        w ) local wait=1 ;;
      esac
    done
    shift $((OPTIND-1))


    _pods=${@}
    if [ -z "${_pods}" ]; then
      _pods=$(getAllPods)
      echoWarning "\nScaling all pods;" ${_pods}\\n
    fi

    for _pod in ${_pods}; do
      scaleDeployment ${_pod}
      if [ ! -z ${wait} ]; then
        waitOnScaleDown ${_pod}
      fi

    done
  )
}

waitOnScaleDown() {
  (
    _deplymentConfigName=${1}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ]; then
      echo -e \\n"waitOnScaleDown; Missing parameter!  You must specify the name of the deployment."\\n
      exit 1
    fi

    deplymentConfigInstance=$(getDeplymentConfigInstanceName ${_deplymentConfigName})
    printf "Waiting for %s to scale to zero " ${_deplymentConfigName}
    while ! isScaledDown ${deplymentConfigInstance}; do
      printf "."
      sleep 1
    done
    echo -e \\n
  )
}

isScaledDown() {
  (
    _deplymentConfigInstance=${1}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ]; then
      echo -e \\n"isScaledDown; Missing parameter!  You must specify the instance name of the deployment."\\n
      exit 1
    fi

    _podCount=$(getPodCount ${_deplymentConfigInstance})
    if ((${_podCount} == 0)); then
      return 0
    else
      return 1
    fi
  )
}

scaleDeployment() {
  (
    _deplymentConfigName=${1}
    _numReplicas=${2:-0}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ] || [ -z "${_numReplicas}" ]; then
      echo -e \\n"scaleDeployment; Missing parameter!  You must specify the name of at least one pod."\\n
      exit 1
    fi

    oc scale -n ${_namespace} --replicas=${_numReplicas} dc ${_deplymentConfigName}
  )
}

getDeplymentConfigInstanceName() {
  (
    _deplymentConfigName=${1}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ]; then
      echo -e \\n"getDeplymentConfigInstanceName; Missing parameter!  You must specify the name of the deployment."\\n
      exit 1
    fi

    deplymentConfigInstance=${_deplymentConfigName}-$(oc -n ${_namespace} get dc ${_deplymentConfigName} --template "{{ .status.latestVersion }}")
    echo ${deplymentConfigInstance}
  )
}

getPodCount() {
    _deplymentConfigInstance=${1}
    _namespace=$(getProjectName)
    if [ -z "${_deplymentConfigName}" ]; then
      echo -e \\n"getPodCount; Missing parameter!  You must specify the instance name of the deployment."\\n
      exit 1
    fi

    _podCount=$(oc -n ${_namespace} get pods -l deployment=${_deplymentConfigInstance} --template '{{ range .items }}{{ printf "%s\n" .metadata.name }}{{end}}' --ignore-not-found | wc -l)
    echo ${_podCount}
}

deleteFromPods() {
  _path=${1}
  shift
  _pods=${@}
  if [ -z "${_path}" ] || [ -z "${_pods}" ]; then
    echo -e \\n"deleteFromPods; Missing parameter!"\\n
    exit 1
  fi

  for _pod in ${_pods}; do
    deleteFromPod "${_pod}" "${_path}"
  done
}

deleteFromPod() {
  _podName=${1}
  _path=${2}
  _cmd="rm -rf ${_path}"
  if [ -z "${_podName}" ] || [ -z "${_path}" ]; then
    echo -e \\n"deleteFromPod; Missing parameter!"\\n
    exit 1
  fi

  runInContainer -v "${_podName}" "${_cmd}"
}

getProjectName() {
  _projectName=${1:-${FULLY_QUALIFIED_NAMESPACE:-${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME}}}
  echo "${_projectName}"
}

switchProject() {
  _projectName=$(getProjectName ${1})

  echoWarning "switchProject has been deprecated in favor of using the oc -n option to specify the target namespace."
  echoWarning "Please update your scripts accordingly."

  echo "Switching to ${_projectName} ..."
  oc project ${_projectName} >/dev/null
}

toLower() {
  echo $(echo ${@} | tr '[:upper:]' '[:lower:]')
}

getAllPods() {
  _pods=${@}
  if [ ! -z "${_pods}" ]; then
    echo "${_pods}"
  else
    oc -n $(getProjectName) get dc | awk '{if(NR>1)print $1}'
  fi
}

removeFromList() {
  _list=${1}
  _remove=${2}
  if [ -z "${_list}" ]; then
    echo -e \\n"removeFromList; Missing parameter!"\\n
    exit 1
  fi

  for _item in ${_remove}; do
    _list=$(echo ${_list} | sed "s~[[:space:]]\+${_item}[[:space:]]\+~ ~g")
  done

  echo ${_list}
}

getOverrideParamFiles() {
  _overrideParamFiles=${@}
  if [ ! -z "${_overrideParamFiles}" ]; then
    echo "${_overrideParamFiles}"
  else
    find . -name "*${OVERRIDE_PARAM_SUFFIX}"
  fi
}

cleanOverrideParamFiles() {
  _overrideParamFiles=$(getOverrideParamFiles ${@})
  for overrideParamFile in ${_overrideParamFiles}; do
    echo -e \\t"Deleting override param file; ${overrideParamFile} ..."
    rm ${overrideParamFile}
  done
}

getConfigFiles() {
  _configFiles=${@}
  if [ ! -z "${_configFiles}" ]; then
    echo "${_configFiles}"
  else
    find . -name "*${DEPLOYMENT_CONFIG_SUFFIX}"
  fi
}

cleanConfigs() {
  _configFiles=$(getConfigFiles ${@})
  for configFile in ${_configFiles}; do
    echo -e \\t"Deleting deployment config file; ${configFile} ..."
    rm ${configFile}
  done
}

getBuildConfigFiles() {
  _configFiles=${@}
  if [ ! -z "${_configFiles}" ]; then
    echo "${_configFiles}"
  else
    find ../ -type f -name "*${BUILD_CONFIG_SUFFIX}"
  fi
}

cleanBuildConfigs() {
  _configFiles=$(getBuildConfigFiles ${@})
  for configFile in ${_configFiles}; do
    echo -e \\t"Deleting build config file; ${configFile} ..."
    rm ${configFile}
  done
}

routeExists() {
  (
    routeName=${1}
    projectName=${2:-$(getProjectName)}

    rtnVal=$(oc -n ${projectName} get route ${routeName} -o name --ignore-not-found)
    if [ -z "${rtnVal}" ]; then
      # Route does not exist ..."
        return 1
    else
      # Route exists ..."
        return 0
    fi
  )
}

# Update route configuration including hostname
updateRoutes() {
  (
    deploymentConfigFile=${1}
    projectName=${2:-$(getProjectName)}
    if [ -z "${deploymentConfigFile}" ]; then
      echo -e \\n"updateRoutes; Missing parameter!"\\n
      exit 1
    fi

    # Filter out anything that is not a route ...
    routeConfigs=$(cat ${deploymentConfigFile} | jq 'if .items != null then del(.items[] | select(.kind != "Route")) else del(select(.kind != "Route")) end')
    if [ -z "${routeConfigs}" ] || [ "${routeConfigs}" = "null" ]; then
      # Everything was filtered out, so there is nothing left to update ...
      return 0
    fi

    # Determine if there is anything left ...
    routeConfigsLength=$(echo ${routeConfigs} | jq '.items | length')
    echoWarning "Found ${routeConfigsLength} routes to update ..."

    if (( "${routeConfigsLength}" > 0 )); then
      for (( itemIndex=0; itemIndex<${routeConfigsLength}; itemIndex++ ))
      do
        routeConfig=$(echo ${routeConfigs} | jq ".items[${itemIndex}]")
        routeName=$(echo ${routeConfig} | jq -r '.metadata.name')
        if routeExists "${routeName}" "${projectName}"; then
          echoWarning "Patching ${routeName} ..."
          # The hostname on a route is immutable, so the route needs to be deleted and replaced ...
          # 'oc apply' will not delete and replace the route even if --force is used.
          # 'oc apply' will not update the host field if it has changed.
          # 'oc patch' will not update the route directly.
          # Therefore, 'oc replace' needs to be used to update the route.
          # --force - Forces the delete and replace
          # --save-config - Maintains compatibility with 'oc apply'
          #
          # 'oc patch' is used with --dry-run it retain any additional route configurations such as certificates.
          oc -n ${projectName} patch route ${routeName} --dry-run -o json -p "${routeConfig}" | oc -n ${projectName} replace --force --save-config -f -
        else
          echoWarning "Creating ${routeName} ..."
          echo ${routeConfig} | oc -n ${projectName} $(getOcAction) -f -
        fi

        exitOnError
        echo
      done
    fi
  )
}

deployConfigs() {
  _configFiles=$(getConfigFiles ${@})
  _projectName=$(getProjectName)
  for configFile in ${_configFiles}; do

    if updateOperation; then
      # Update existing routes first ...
      updateRoutes ${configFile}

      # Filter out the routes, since we've already updated them ...
      config=$(cat ${configFile} | jq 'if .items != null then del(.items[] | select(.kind == "Route")) else del(select(.kind == "Route"))  end')
      if [ -z "${config}" ] || [ "${config}" = "null" ]; then
        # Everything was filtered out, so there is nothing left to update ...
        continue
      fi

      echo "${config}" | oc -n ${_projectName} $(getOcAction) -f -
      exitOnError
    else
      oc -n ${_projectName} $(getOcAction) -f ${configFile}
      exitOnError
    fi
  done
}

buildConfigExists() {
  (
    buildName=${1}
    projectName=${2:-$(getProjectName)}

    rtnVal=$(oc -n ${projectName} get bc ${buildName} -o name --ignore-not-found)
    if [ -z "${rtnVal}" ]; then
      # Route does not exist ..."
        return 1
    else
      # Route exists ..."
        return 0
    fi
  )
}

updateBuildConfigs() {
  (
    buildConfigFile=${1}
    projectName=${2:-${TOOLS}}
    if [ -z "${buildConfigFile}" ]; then
      echo -e \\n"updateBuildConfigs; Missing parameter!"\\n
      exit 1
    fi

    # Filter out anything that is not a buildConfig ...
    buildConfigs=$(cat ${buildConfigFile} | jq 'if .items != null then del(.items[] | select(.kind != "BuildConfig")) else del(select(.kind != "BuildConfig")) end')
    if [ -z "${buildConfigs}" ] || [ "${buildConfigs}" = "null" ]; then
      # Everything was filtered out, so there is nothing left to update ...
      return 0
    fi

    # Determine if there is anything left ...
    buildConfigsLength=$(echo ${buildConfigs} | jq '.items | length')
    echoWarning "Found ${buildConfigsLength} buildConfigs to update ..."

    if (( "${buildConfigsLength}" > 0 )); then
      for (( itemIndex=0; itemIndex<${buildConfigsLength}; itemIndex++ ))
      do
        buildConfig=$(echo ${buildConfigs} | jq ".items[${itemIndex}]")
        buildName=$(echo ${buildConfig} | jq -r '.metadata.name')
        if buildConfigExists "${buildName}" "${projectName}"; then
          echoWarning "Patching ${buildName} ..."
          # Filter out the triggers from the new config so we can retain the existing ones
          filteredConfig=$(echo "${buildConfig}" | jq 'if .items != null then del(.items[] | select(.kind == "BuildConfig") | .spec.triggers) else del(select(.kind == "BuildConfig") | .spec.triggers) end')
          # 'oc patch' is used with --dry-run it retain the trigger settings of the exiting buildConfig.
          # This ensures exiting webhooks are not broken when the build is updated.
          oc -n ${projectName} patch bc ${buildName} --dry-run -o json -p "${filteredConfig}" | oc -n ${projectName} $(getOcAction) -f -
        else
          echoWarning "Creating ${buildName} ..."
          echo ${buildConfig} | oc -n ${projectName} $(getOcAction) -f -
        fi

        exitOnError
        echo
      done
    fi
  )
}

deployBuildConfigs() {
  _configFiles=$(getBuildConfigFiles ${@})
  projectName=${TOOLS}

  for configFile in ${_configFiles}; do
    if updateOperation; then
      # Update existing buildConfigs first ...
      updateBuildConfigs ${configFile}

      # Filter out the buildConfigs, since we've already updated them ...
      config=$(cat ${configFile} | jq 'if .items != null then del(.items[] | select(.kind == "BuildConfig")) else del(select(.kind == "BuildConfig"))  end')
      numItems=$(echo ${config} | jq '.items | length')
      if (( "${numItems}" <= 0 )); then
        # Everything was filtered out, so there is nothing left to update ...
        continue
      fi

      echo "${config}" | oc -n ${projectName} $(getOcAction) -f -
      exitOnError
    elif createOperation; then
      oc -n ${projectName} $(getOcAction) -f ${configFile}
      exitOnError
    else
      echoError "\nUnrecognized operation, $(getOperation).  Unable to process build configuration.\n"
      exit 1
    fi
  done
}

# =================================================================================================================
# runInContainer
# - Running with the '-v' switch provides additional log output.
# -----------------------------------------------------------------------------------------------------------------
runInContainer() {
  (
    local OPTIND
    local unset _verbose
    local unset _flags
    while getopts vi FLAG; do
      case $FLAG in
        v ) local _verbose=1 ;;
        i ) local _flags="-i -t" ;;
      esac
    done
    shift $((OPTIND-1))

    _podName=${1}
    _command=${2}
    _podIndex=${3:-0}
    if [ -z "${_podName}" ] || [ -z "${_command}" ]; then
      echo -e \\n"runInContainer; Missing parameter!"\\n
      exit 1
    fi

    if [ "$OSTYPE" == "msys" ] && [ ! -z "${_flags}" ]; then
      OC_CMD="winpty oc"
    else
      OC_CMD="oc"
    fi

    # Get name of a currently deployed pod by label and index
    _podInstanceName=$(getPodByName "${_podName}" "${_podIndex}")
    if [ ! -z "${_podInstanceName}" ]; then
      if [ ! -z "${_verbose}" ]; then
        echo -e "\nExecuting command on $(getProjectName)/${_podInstanceName}:"
        echo -e "\t${_command}\n"
      fi
      ${OC_CMD} exec ${_flags} -n $(getProjectName) "${_podInstanceName}" -- bash -c "${_command:-echo Hello}"
    else
      if [ ! -z "${_verbose}" ]; then
        echoWarning "\nrunInContainer; a running instance of $(getProjectName)/${_podName} was not found.\n"
      fi
    fi
  )
}

runInContainerInteractively() {
  _podName=${1}
  _command=${2:-echo Hello}
  if [ -z "${_podName}" ] || [ -z "${_command}" ]; then
    echo -e \\n"runInContainerInteractively; Missing parameter!"\\n
    exit 1
  fi

  echoWarning "\nrunInContainerInteractively is deprecated, use 'runInContainer -i' instead."

  _podInstanceName=$(getPodByName ${_podName})
  exitOnError

  echo
  echo "Executing command on ${_podInstanceName}:"
  echo -e "\t${_command}"
  echo

  oc -n $(getProjectName) exec -i "${_podInstanceName}" -- bash -c "${_command}"
}

isInstalled(){
  rtnVal=$(type "$1" >/dev/null 2>&1)
  rtnCd=$?
  if [ ${rtnCd} -ne 0 ]; then
    return 1
  else
    return 0
  fi
}

# =================================================================================================================
# getPodByName
# - The eventual replacement for the discrete getPodByName.sh script
# -----------------------------------------------------------------------------------------------------------------
getPodByName() {
  (
    _podName=${1}
    _podIndex=${2:-0}
    if [ -z "${_podName}" ] ; then
      echo -e \\n"getPodByName; Missing parameter!"\\n
      exit 1
    fi

    _podInstanceName=$(getPodNameByLabel "${_podName}" "name" "${_podIndex}")
    if [ -z "${_podInstanceName}" ] ; then
      _podInstanceName=$(getPodNameByLabel "${_podName}" "app" "${_podIndex}")
    fi

    if [ -z "${_podInstanceName}" ]; then
      echoWarning "\ngetPodByName; a running instance of '${_podName}' was not found.\n"
    fi

    echo ${_podInstanceName}
  )
}

getPodNameByLabel() {
  (
    _podName=${1}
    _label=${2:-name}
    _podIndex=${3:-0}
    if [ -z "${_podName}" ] ; then
      echo -e \\n"getPodNameByLabel; Missing parameter!"\\n
      exit 1
    fi

    if [[ _podIndex > 0 ]] ; then
      # Get the pod name using the specified pod index ...
      _podInstanceName=$(oc get pods -n $(getProjectName) -l "${_label}=${_podName}" --template "{{ with index .items ${_podIndex} }}{{ .metadata.name }}{{ end }}" --ignore-not-found)
    else
      # Get the name of the first "Ready" pod ...
      _podInstanceName=$(oc get pods -n $(getProjectName) -l "${_label}=${_podName}" --template '{{ range $item := .items }}{{ range .status.conditions }}{{ if and (eq .type "Ready") (eq .status "True") }}{{ printf "%s\n" $item.metadata.name }}{{end}}{{end}}{{end}}' --ignore-not-found | head -n 1)
    fi
    echo ${_podInstanceName}
  )
}
# =================================================================================================================

readConf(){
  (
    local OPTIND
    local OPTARG
    unset local flatten
    unset local delimiter
    while getopts fd: FLAG; do
      case $FLAG in
        f )
          local flatten=1
          ;;
        d )
          local delimiter=${OPTARG}
          ;;
      esac
    done
    shift $((OPTIND-1))

    # Comma delimit by default ...
    if [ -z ${delimiter} ]; then
      delimiter=','
    fi

    configFile=${1}
    if [ -f ${configFile} ]; then
      # Read in the config minus any comments ...
      echo -e \\n"Reading config from ${configFile} ..." >&2
      _value=$(sed '/^[[:blank:]]*#/d;s/#.*//' ${configFile})

      if [ ! -z ${flatten} ]; then
        # flatten into a single line delimited string ...
        filters=":a;N;\$!ba;s~\n~${delimiter}~g;"
        _value=$(echo "${_value}" | sed "${filters}")
      fi
    fi

    echo "${_value}"
  )
}

readIntoSingleLine() {
  (
    path=${1}
    if [ ! -f ${path} ]; then
      echo -e \\n"readIntoSingleLine - Unable to locate file - ${path}"\\n
      exit 1
    fi

    singleLine=$(sed ':a;N;$!ba;s/\n/\\n/g' ${path})
    echo ${singleLine}
  )
}

ROUTE_CERTIFICATE_PATCH_TEMPLATE='{\"spec\": {\"tls\": {\"certificate\": \"${certificate}\",\"key\": \"${privateKey}\"}}}'
getCertificatePatch() {
  (
    certPath=${1}
    pkPath=${2}
    if [ ! -f ${certPath} ] || [ ! -f ${pkPath} ]; then
      echoWarning "getCertificatePatch; Unable to locate one of the required files!" >&2
      echoWarning "Certificate: ${certPath}" >&2
      echoWarning "Private Key: ${pkPath}"\\n >&2
      exit 1
    fi

    certificate=$(readIntoSingleLine ${certPath})
    privateKey=$(readIntoSingleLine ${pkPath})
    patch="'"$(eval echo ${ROUTE_CERTIFICATE_PATCH_TEMPLATE})"'"
    echo ${patch}
  )
}

isProjectRoute() {
  (
    projectName=${1}
    route=${2}

    IFS=","
    params=(${route})
    unset IFS
    targetProjectName=${params[0]}

    if [[ ${targetProjectName} == ${projectName} ]]; then
      return 0
    else
      return 1
    fi
  )
}

deployCertificates() {
  (
    configFile=${1:-certificate.conf}
    projectName=$(getProjectName)
    if [ ! -z ${configFile} ] && [ -f ${configFile} ]; then
      echo -e \\n"Found ${configFile} file, attempting to install certificates ..."
      routes=$(readConf ${configFile})
      installCertificates "${projectName}" "${routes}"
    fi
  )
}

installCertificates() {
  (
    projectName=${1}
    routes=${2}
    if [ -z "${projectName}" ] || [ -z "${routes}" ] ; then
      echo -e \\n"installCertificates; Missing parameter!"\\n
      exit 1
    fi

    for route in ${routes}; do
      if isProjectRoute "${projectName}" "${route}"; then
        installCertificate "${route}"
      fi
    done
  )
}

installCertificate() {
  (
    case "$1}" in
      *,*)
        IFS=","
        params=(${1})
        unset IFS
        projectName=${params[0]}
        routeName=${params[1]}
        certPath=${params[2]}
        pkPath=${params[3]}
        ;;
      *)
        projectName=${1}
        routeName=${2}
        certPath=${3}
        pkPath=${4}
    esac

    if [ -z ${projectName} ] || [ -z ${routeName} ] || [ -z ${certPath} ] || [ -z ${pkPath} ]; then
      echo -e \\n"installCertificate; Missing one or more parameters!"\\n
      exit 1
    fi

    if [ -f ${certPath} ] && [ -f ${pkPath} ]; then
      resourceType="route"
      echo "Installing certificate [${certPath}] and private key [${pkPath}] on route [${routeName}] in project [${projectName}] ..."

      unset certPatch
      certPatch=$(getCertificatePatch "${certPath}" "${pkPath}")

      if [ ! -z "${certPatch}" ]; then
        eval oc -n ${projectName} patch ${resourceType} ${routeName} -p ${certPatch}
      else
        echoError "Unable to install the certificate.  To install the certificate please ensure copies of the certificate and private key exist in the specified location."
      fi
    else
      echoWarning "Neither '${certPath}' nor '${pkPath}' where found.  Skipping certificate installation."
    fi
  )
}

transferRoutes() {
  (
    fromProject=${1}
    toProject=${2}
    routes=${3}
    tmpFile="transferRoute_DeploymentConfig.json"
    if [ -z "${routes}" ] || [ -z "${fromProject}" ] || [ -z "${toProject}" ]; then
      echo -e \\n"transferRoutes; Missing parameter!"\\n
      exit 1
    fi

    printAndAskToContinue "Transfering Routes - If you contiune the following routes will be transfered from ${fromProject} to ${toProject}:\n${routes}\n"
    for route in ${routes}; do
      oc -n ${fromProject} export route ${route} > ${tmpFile}
      exitOnError
      echo "route \"${route}\" exported"
      oc -n ${toProject} create -f ${tmpFile}
      exitOnError
      rm ${tmpFile}
      exitOnError
      oc -n ${fromProject} delete route ${route}
      exitOnError
    done
  )
}

untagImages() {
  _appName=${1}
  if [ -z "${_appName}" ]; then
    echoError "\nuntagAllImages; You MUST specify the name to use when filtering on the 'app' label.\n"
    exit 1
  fi

  printAndAskToContinue "If you contiune the all of the tags from any image associated to '${_appName}' will be deleted."

  appImages=$(oc -n ${TOOLS} get is -l app=${_appName} --template '{{ range .items }}{{ printf "%s\n" .metadata.name}}{{end}}')
  for appImage in ${appImages}; do
    sourceTags=$( oc -n ${TOOLS} get is ${appImage} --template '{{ range .spec.tags }}{{ printf "%s\n" .name}}{{end}}')
    for sourceTag in ${sourceTags}; do
      oc -n ${TOOLS} tag ${appImage}:${sourceTag} -d
    done
  done
}

# =================================================================================================================
# Database Managment Functions:
# -----------------------------------------------------------------------------------------------------------------
dropAndRecreatePostgreSqlDatabase() {
  # This function drops and recreates a PostgreSql database on a remote pod.
  # You must specify the friendly name of the pod hosting the database.
  # The associated database infomration including Database Name and Username
  # are assumed to exist on the pod in environment variables; ${POSTGRESQL_DATABASE} and ${POSTGRESQL_USER}.
  _databasePodName=${1}
  if [ -z "${_databasePodName}" ]; then
    echo -e \\n"dropAndRecreatePostgreSqlDatabase; Missing parameter!"\\n
    exit 1
  fi

  echo "============================================================================="
  echo "Recreating database ..."
  echo "-----------------------------------------------------------------------------"
  runInContainer -v \
  ${_databasePodName} \
  'psql -ac "DROP DATABASE \"${POSTGRESQL_DATABASE}\";"'

  runInContainer -v \
  ${_databasePodName} \
  'psql -ac "CREATE DATABASE \"${POSTGRESQL_DATABASE}\";"'

  runInContainer -v \
  ${_databasePodName} \
  'psql -ac "GRANT ALL ON DATABASE \"${POSTGRESQL_DATABASE}\" TO \"${POSTGRESQL_USER}\";"'
  echo "============================================================================"
  echo

  echo "============================================================================="
  echo "Listing databases ..."
  echo "-----------------------------------------------------------------------------"
  runInContainer -v \
  ${_databasePodName} \
  'psql -c "\l"'
  echo "============================================================================"
  echo
}

dropAndRecreateDatabaseWithMigrations() {
  (
    # This function drops and recreates a PostgreSql database who's schema
    # is managed by migrations hosted on an API pod.
    #
    # The function is purposely wrapped in a subshell `(...)` to avoid variable name collisions.
    local OPTIND
    unset local autoScale
    unset local flags
    while getopts a FLAG; do
      case $FLAG in
        a )
          local autoScale=1
          local flags="-w"
          ;;
      esac
    done
    shift $((OPTIND-1))

    local apiPodName=${1}
    local dbPodName=${2}
    if [ -z "${apiPodName}" ] || [ -z "${dbPodName}" ]; then
      echo -e \\n"dropAndRecreateDatabaseWithMigrations; Missing parameter!"\\n
      exit 1
    fi

    scaleDown ${flags} ${apiPodName}
    exitOnError
    if [ -z ${autoScale} ]; then
      printAndWait "Wait for the ${apiPodName} pod to completely shut down before continuing."
    fi

    dropAndRecreatePostgreSqlDatabase ${dbPodName}
    exitOnError

    scaleUp ${flags} ${apiPodName}
    exitOnError
    if [ -z ${autoScale} ]; then
      printAndWait "Wait for the ${apiPodName} pod to completely start up and ensure it has finished running the database migrations before continuing."
    fi
  )
}

deleteAndRecreateDatabaseWithMigrations() {
  (
    # This function DELETES and recreates a PostgreSql database who's schema
    # is managed by migrations hosted on an API pod.
    #
    # The function is purposely wrapped in a subshell `(...)` to avoid variable name collisions.
    _apiPodName=${1}
    _dbPodName=${2}
    if [ -z "${_apiPodName}" ] || [ -z "${_dbPodName}" ]; then
      echo -e \\n"deleteAndRecreateDatabaseWithMigrations; Missing parameter!"\\n
      exit 1
    fi

    scaleDown ${_apiPodName}
    exitOnError

    printAndWait "Wait for the ${_apiPodName} pod to completely shut down before continuing."

    deletePostgreSqlDatabase ${_dbPodName}
    exitOnError

    scaleDown ${_dbPodName}
    exitOnError

    printAndWait "Wait for the ${_dbPodName} pod to completely shut down before continuing."

    scaleUp ${_dbPodName}
    exitOnError

    printAndWait "Wait for the ${_dbPodName} pod to completely start up before continuing."

    scaleUp ${_apiPodName}
    exitOnError

    printAndWait "Wait for the ${_apiPodName} pod to completely start up and ensure it has finished running the database migrations before continuing."
  )
}

deleteAndRecreateDatabase() {
  (
    # This function DELETES and recreates a PostgreSql database who's schema
    # is managed by migrations hosted on some other pod.
    #
    # The function is purposely wrapped in a subshell `(...)` to avoid variable name collisions.
    _dbPodName=${1}
    if [ -z "${_dbPodName}" ]; then
      echo -e \\n"deleteAndRecreateDatabase; Missing parameter!"\\n
      exit 1
    fi

    deletePostgreSqlDatabase ${_dbPodName}
    exitOnError

    scaleDown ${_dbPodName}
    exitOnError

    printAndWait "Wait for the ${_dbPodName} pod to completely shut down before continuing."

    scaleUp ${_dbPodName}
    exitOnError

    printAndWait "Wait for the ${_dbPodName} pod to completely start up before continuing."
  )
}

deletePostgreSqlDatabase() {
  # This function deletes a PostgreSql database on a remote pod.
  # You must specify the friendly name of the pod hosting the database.
  # The associated database infomration including Database Name and Username
  # are assumed to exist on the pod in environment variables; ${POSTGRESQL_DATABASE} and ${POSTGRESQL_USER}.
  _databasePodName=${1}
  _dataDirectory=${2:-"/var/lib/pgsql/data/userdata"}
  if [ -z "${_databasePodName}" ]; then
    echo -e \\n"deletePostgreSqlDatabase; Missing parameter!"\\n
    exit 1
  fi

  echo "============================================================================="
  echo "Deleting the database ..."
  echo "-----------------------------------------------------------------------------"
  deleteFromPod "${_databasePodName}" "${_dataDirectory}"
}

getPostgreSqlDatabaseDiskUsage() {
  # This function opperates on a PostgreSql database on a remote pod.
  # You must specify the friendly name of the pod hosting the database.
  _databasePodName=${1}
  _dataDirectory=${2:-"/var/lib/pgsql/data"}
  if [ -z "${_databasePodName}" ]; then
    echoError \\n"getPostgreSqlDatabaseDiskUsage; Missing parameter!"\\n
    exit 1
  fi

  runInContainer "${_databasePodName}" "df -h ${_dataDirectory}"
}

function getRecordCounts() {
  # -------------------------------------------------------------------------------
  # Get a list of record counts for a given database.
  # Produces a list of tables with the total number of records in each table
  # along with the amount of disk used by each table.
  # -------------------------------------------------------------------------------
  _dbPodName=${1}
  _databaseName=${2}
  _resourceSuffix=${3:-${resourceSuffix}}

  # echoWarning "_dbPodName: ${_dbPodName}"
  # echoWarning "_databaseName: ${_databaseName}"
  # echoWarning "_resourceSuffix: ${_resourceSuffix}"

  if [ -z "${_dbPodName}" ]; then
    echoError "\ngetRecordCounts; You MUST specify the name of the database pod.\n"
    exit 1
  fi

  if [ -z ${_databaseName} ]; then
    _databaseName="\${POSTGRESQL_DATABASE}"
  fi

  command='
    create or replace function
    count_rows(schema text, tablename text) returns integer
    as
    \$body$
    declare
      result integer;
      query varchar;
    begin
      query := '"'"'SELECT count(1) FROM '"'"' || schema || '"'"'.'"'"' || tablename;
      execute query into result;
      return result;
    end;
    \$body$
    language plpgsql;
  '
  runInContainer \
    ${_dbPodName}${_resourceSuffix} \
    "psql -d "${_databaseName}" -q -c \"${command}\""

  echo
  command='
    select
      table_schema,
      table_name,
      count_rows(table_schema, table_name),
      pg_size_pretty( pg_total_relation_size(table_name) ) as disk_usage
    from information_schema.tables
    where
      table_schema not in ('"'"'pg_catalog'"'"', '"'"'information_schema'"'"')
      and table_type='"'"'BASE TABLE'"'"'
    order by 3 desc;
  '
  runInContainer \
    ${_dbPodName}${_resourceSuffix} \
    "psql -d "${_databaseName}" -c \"${command}\""
}

function listDatabases() {
  _dbPodName=${1}
  if [ -z "${_dbPodName}" ]; then
    echoError "\nlistDatabases; You MUST specify the name of the database pod.\n"
    exit 1
  fi

  echo
  runInContainer \
    ${_dbPodName}${resourceSuffix} \
    'psql -c "\l"'
}

function getConnections() {
  (
    # ------------------------------------------------------------------
    # Get database connection information for the specified database
    # ------------------------------------------------------------------
    _dbPodName=${1}
    if [ -z "${_dbPodName}" ]; then
      echoError "\ngetConnections; You MUST specify the name of the database pod.\n"
      exit 1
    fi

    # Query taken from here:
    # https://dba.stackexchange.com/questions/161760/number-of-active-connections-and-remaining-connections
    command='
      select max_conn,used,res_for_super,max_conn-used-res_for_super res_for_normal
      from
        (select count(*) used from pg_stat_activity) t1,
        (select setting::int res_for_super from pg_settings where name=\$\$superuser_reserved_connections\$\$) t2,
        (select setting::int max_conn from pg_settings where name=\$\$max_connections\$\$) t3;
    '
    echo
    echo "=============================================================="
    echo "Database connection details for ${_dbPodName}${resourceSuffix}:"
    echo "--------------------------------------------------------------"
    runInContainer \
      ${_dbPodName}${resourceSuffix} \
      "psql -c \"${command}\""
    echo "=============================================================="
  )
}

# Drops a specific database from a postgresql container.
# If a databasename is not provided the default '${POSTGRESQL_DATABASE}' database is assumed.
function dropDatabase() {
  (
    _podName=${1}
    _databasename=${2}
    if [ -z "${_podName}" ]; then
      echoError "\ndropDatabase; You MUST specify a pod name.\n"
      exit 1
    fi

    if [ -z "${_databasename}" ]; then
      databaseName="default"
      cmd='psql -ac "DROP DATABASE \"${POSTGRESQL_DATABASE}\";"'
    else
      databaseName="${_databasename}"
      cmd="psql -ac 'DROP DATABASE \"${_databasename}\";'"
    fi

    printAndAskToContinue "If you contiune the ${databaseName} database on $(getProjectName)/${_podName}${resourceSuffix} will be dropped.  All data will be lost."
    runInContainer -v \
      ${_podName}${resourceSuffix} \
      "${cmd}"
    echoWarning "\nThe ${databaseName} database on $(getProjectName)/${_podName}${resourceSuffix} has been dropped."
  )
}
# =================================================================================================================

# =================================================================================================================
# Hyperledger Indy Specific Functions:
# -----------------------------------------------------------------------------------------------------------------
# You need to supply your own getLedgerAddress implementation.
# -----------------------------------------------------------------------------------------------------------------
deleteWallets() {
  _podNames=${@}
  if [ -z "${_podNames}" ]; then
    echo -e \\n"deleteWallets; Missing parameter!  You must specify the name of at least one pod."\\n
    exit 1
  fi

  printAndAskToContinue "If you contiune the wallets from ${_podNames} will be deleted.  All data will be lost."
  deleteFromPods "/home/indy/.indy_client/wallet/*" ${_podNames}
}

registerDids() {
  _names=${@}
  if [ -z "${_names}" ]; then
    echo -e \\n"registerDids; Missing parameter!"\\n
    exit 1
  fi

  for _name in ${_names}; do
    registerDid ${_name}
  done
}

registerDid() {
  _name=${1}
  if [ -z "${_name}" ]; then
    echo -e \\n"registerDid; Missing parameter!"\\n
    exit 1
  fi
  _seedData=$(getSeedData ${_name})
  _ledgerAddress=$(getLedgerAddress)
  _ledgerUri="http://${_ledgerAddress}/register"

  echo -e \\n"Registering ${_name} with the ledger ..."
  curl -X POST \
    ${_ledgerUri} \
    -H 'content-type: application/json' \
    -d "${_seedData}"
}

getSeedData() {
  _name=${1}
  if [ -z "${_name}" ]; then
    echo -e \\n"getSeedData; Missing parameter!"\\n
    exit 1
  fi

  _seed=$(generateSeed $(getSeedName ${_name}))
  echo "{\"seed\": \"${_seed}\"}"

}

getSeedName() {
  _name=${1}
  if [ -z "${_name}" ]; then
    echo -e \\n"getSeedName; Missing parameter!"\\n
    exit 1
  fi

  echo "${_name}_${DEPLOYMENT_ENV_NAME}_"
}

generateSeed() {
  _name=${1}
  if [ -z "${_name}" ]; then
    echo -e \\n"generateSeed; Missing parameter!"\\n
    exit 1
  fi

  _seed=$(printf "%s%0$((32-${#_name}))d" ${_name} 0)
  echo ${_seed}
}
# =================================================================================================================

function getSecret() {
  (
    resourceName=${1}
    key=${2}
    projectName=${3:-$(getProjectName)}
    if [ -z "${resourceName}" ] || [ -z "${key}" ]; then
      echoError "\ngetSecret; You must specify the 'resourceName' and 'key'.\n"
      exit 1
    fi

    echo $(oc -n ${projectName} extract --to=- --keys=${key} secret/${resourceName} 2>&1 | sed -n 2p)
  )
}

function buildPullSecret(){
  USE_PULL_CREDS=${1}
  CRED_SEARCH_NAMES=${2}
  PULL_CREDS=${3}
  DOCKER_REG=${4}
  PROMPT_CREDS=${5}
  CRED_ENVS=${6}

  #build the credentials
  if [ ! -z ${USE_PULL_CREDS} ] && [ ${USE_PULL_CREDS} = true ]; then
    if [ ! -z ${PROMPT_CREDS} ] && [ ${PROMPT_CREDS} = true ]; then
      registerPullSecretPrompt "${PROJECT_NAMESPACE}" "${PULL_CREDS}" "${DOCKER_REG}" "${CRED_ENVS[@]}" "${DOCKER_USERNAME}" "${DOCKER_PASSWORD}"
    else
      registerPullSecret "${PROJECT_NAMESPACE}" "${CRED_SEARCH_NAMES}" "${PULL_CREDS}" "${DOCKER_REG}" "${CRED_ENVS[@]}"
    fi
  fi
}

function registerPullSecretPrompt(){
  namespaceName=${1}
  newCredName=${2}
  dockerReg=${3}
  credEnvs=${4}
  userName=${5}
  password=${6}

  if ([ -z ${userName} ] || [ -z ${password} ]); then
    echoWarning "Please enter your ${dockerReg} username"
    read userName

    echoWarning "Please enter your ${dockerReg} password or login token"
    read password
  fi

  #set cred env to tools if unset
  if [ -z "${credEnvs}" ]; then
    credEnvs="tools"
  fi
  #create pull secret in each environment we need
  for env in ${credEnvs}; do
    cred_exists=0
    oc create secret docker-registry ${newCredName} -n ${namespaceName}-${env} \
      --docker-server=${dockerReg} \
      --docker-username=${userName} \
      --docker-password=${password} \
      --docker-email=${userName}@${namespaceName}-${env}.local &> /dev/null || cred_exists=1
    if (( ! ${cred_exists})); then
      echoWarning "\nCreated new pull secret, ${newCredName}, in ${namespaceName}-${env} ..."
    else
      echoWarning "\nPull secret, ${newCredName} already exists in ${namespaceName}-${env} ..."
    fi

    # Always link / relink the pull secret to the service accounts ...
    echoWarning "Linking pull secret, ${newCredName}, to the default service account in ${namespaceName}-${env} ..."
    # --for=pull is required for builds and deployments to be able to authenticate correctly when pulling images
    oc -n ${namespaceName}-${env} secrets link default ${newCredName} --for=pull

    echoWarning "Linking pull secret, ${newCredName}, to the builder service account in ${namespaceName}-${env} ..."
    oc -n ${namespaceName}-${env} secrets link builder ${newCredName}
  done
}

function registerPullSecret() {
    namespaceName=${1}
    credSearchNames=${2}
    newCredName=${3}
    dockerReg=${4}
    credEnvs=${5}

    for credSearchName in ${credSearchNames}; do
      credSearchFilter+="${credSearchName}\|"
    done
    credSearchFilter=$(echo ${credSearchFilter} | sed 's~[\|]*$~~g')

    credName=$(oc -n ${namespaceName}-tools get secrets --template '{{ range $item := .items }}{{ if (eq $item.type "kubernetes.io/basic-auth") }}{{ printf "%s\n" $item.metadata.name}}{{ end }}{{end}}' | sed -n "/${credSearchFilter}/p")
    userName=$(getSecret ${credName} username ${namespaceName}-tools)
    password=$(getSecret ${credName} password ${namespaceName}-tools)

    # If we fail to find cred search name do nothing
    if [ ! -z ${credName} ] && [ ! -z ${userName} ] && [ ! -z ${password} ]; then
      echoWarning "Found secret ${credName}, would you like to use this as a pull secret? (y/n)"
      read resp
      if [ ${resp} = "y" ]; then
        registerPullSecretPrompt ${namespaceName} ${newCredName} ${dockerReg} "${credEnvs[@]}" ${userName} ${password}
      else
        echo "Done!"
      fi
    fi
}

function listBuildRefs() {
  # Lists build configurations and their git references in a convenient column format.
  (
    projectName=${1:-${TOOLS}}
    echo
    oc -n ${projectName} get bc --template '{{ range .items }}{{ printf "%s,%s,%s\n" .metadata.name .spec.source.git.uri .spec.source.git.ref}}{{end}}' | sed 's~%!s(<nil>)~-~g' | column -t -s ,
  )
}


function yqIsInstalled()
{
  (
    # Check for dependancies
    YQ_EXE=yq
    if ! isInstalled ${YQ_EXE}; then
        echoWarning "\nThe ${YQ_EXE} executable is required and was not found on your path.\n"

cat <<-EOF
The recommended approach to installing the required package(s) is to use either [Homebrew](https://brew.sh/) (MAC)
or [Chocolatey](https://chocolatey.org/) (Windows).

Windows:
  - chocolatey install ${YQ_EXE}

MAC:
  - brew install ${YQ_EXE}
EOF
        exit 1
    fi

    exit 0
  )
}

function convertJsonToYaml() {
  (
    if ! yqIsInstalled; then
      exit 1
    fi

    # Get a list of json formatted configuration files for the project ...
    templates=$(getConfigTemplates $(getTemplateDir) 2>/dev/null)
    for template in ${templates}; do
      if [[ "${template}" == *.json ]]; then
        jsonTemplates+=" ${template}"
      fi
    done

    # echo -e "\nConfiguration Templates:"
    # for template in ${templates}; do
    #   echo "  ${template}"
    # done

    if [ ! -z "${jsonTemplates}" ]; then
      echoWarning "\nIf you continue, the following configuration files will be converted from json to yaml format:\n"
      for template in ${jsonTemplates}; do
        echo "  ${template}"
      done
      printAndAskToContinue " "

      for template in ${jsonTemplates}; do
        outputFilename=$(echo ${template} | sed "s~.json~.yaml~g")
        echo "Converting ${template} to yaml and writing the content to ${outputFilename} ..."
        yq eval --prettyPrint "${template}" > "${outputFilename}"
        exitOnError

        echo -e "Removing ${template} ...\n"
        rm "${template}"
      done
    else
      echoWarning "\nNo json formatted configuration files were found in your project ..."
    fi
  )
}

function getRoutes()
{
  (
    local OPTIND
    unset local filter
    unset local cluster
    while getopts f:d: FLAG; do
      case $FLAG in
        f )
          local filter=${OPTARG}
          ;;
        d )
          local cluster=${OPTARG}
          ;;
      esac
    done
    shift $((OPTIND-1))

    if [ ! -z "${cluster}" ]; then
      context=$(oc config get-contexts | sed 's/*/ /g' | grep ${cluster} | awk '{print $1}' | head -n 1)
    else
      context=$(oc config current-context)
    fi

    if [ -z ${FULLY_QUALIFIED_NAMESPACE} ]; then
      projects=$(oc --context=${context} projects -q)
    else
      projects=$(getProjectName)
    fi

    if [ ! -z "${filter}" ]; then
      echoWarning "\nFiltering route list on '${filter}' ..."
    fi

    for project in ${projects}; do
      routes=$(oc -n ${project} --context=${context} get route --template '{{ range $item := .items }}{{if $item.spec.path}}{{ printf "%s,%s%s\n" $item.metadata.name $item.spec.host $item.spec.path}}{{ else }}{{ printf "%s,%s\n" $item.metadata.name $item.spec.host}}{{end}}{{end}}')

      if [ ! -z "${filter}" ]; then
        routes=$(echo "${routes}" | grep "${filter}")
      fi

      if [ ! -z "${routes}" ]; then
        echoWarning \\n"${project}:"
        echo -e "NAME:,HOST:\n${routes}" | column -t -s ,
      fi
    done
  )
}

function getAllowLists()
{
  (
    local OPTIND
    unset local filter
    unset local cluster
    while getopts f:d: FLAG; do
      case $FLAG in
        f )
          local filter=${OPTARG}
          ;;
        d )
          local cluster=${OPTARG}
          ;;
      esac
    done
    shift $((OPTIND-1))

    if [ ! -z "${cluster}" ]; then
      context=$(oc config get-contexts | sed 's/*/ /g' | grep ${cluster} | awk '{print $1}' | head -n 1)
    else
      context=$(oc config current-context)
    fi

    if [ -z ${FULLY_QUALIFIED_NAMESPACE} ]; then
      projects=$(oc --context=${context} projects -q)
    else
      projects=$(getProjectName)
    fi

    # Filter the project list ...
    if [ ! -z "${filter}" ]; then
      echoWarning "\nFiltering project list on '${filter}' ..."
      projects=$(echo "${projects}" | grep "${filter}")
    fi

    for project in ${projects}; do
      allowLists=$(oc -n ${project} --context=${context} get route --template '{{ range $item := .items }}{{ range $key,$value := .metadata.annotations }}{{ if (eq $key "haproxy.router.openshift.io/ip_whitelist") }}{{ printf "%s,%s\n" $item.metadata.name $value }}{{ end }}{{ end }}{{end}}')
      if [ ! -z "${allowLists}" ]; then
        echoWarning \\n"${project}:"
        echo -e "NAME:,ALLOW LIST:\n${allowLists}" | column -t -s ,
      fi
    done
  )
}

export OC_FUNCTIONS_LOADED=1