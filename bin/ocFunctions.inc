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
  _msg=${1}
  _yellow='\033[1;33m'
  _nc='\033[0m' # No Color
  echo -e "${_yellow}${_msg}${_nc}"
}

echoError (){
  _msg=${1}
  _red='\033[0;31m'
  _nc='\033[0m' # No Color
  echo -e "${_red}${_msg}${_nc}"
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
    _podInstanceName=$(getPodByName.sh ${_podName} ${_podIndex})
    if [ ! -z "${_podInstanceName}" ]; then
      # The pod exists ...
      return 0
    else
      # The pod does not exist ...
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
  oc process --parameters --filename=${_template} | \
    sed '1d' | \
    awk -F'[ ]{2,}' '{ print $1 "=" $NF }' | \
    sed 's~\(^GITHUB_WEBHOOK_SECRET=.*$\)~#\1~' | \
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
  echo $(find . -name "*Jenkinsfile")
}

getConfigTemplates () {
  echo $(find . -regex "^.*\.\(json\|yaml\|yml\)" -exec grep -l "DeploymentConfig\|BuildConfig\|Route\|\"ImageStream\"\|kind:.ImageStream$" '{}' \; | xargs | sed "s/\.\///g")
}

getBuildTemplates () {
  _searchPath=${1}
   if [ -z "${_searchPath}" ]; then
    echo -e \\n"getBuildTemplates; Missing parameter!"\\n
    exit 1
  fi

  echo $(find ${_searchPath} -regex "^.*\.\(json\|yaml\|yml\)" -exec grep -l "BuildConfig\|\"ImageStream\"\|kind:.ImageStream$" '{}' \; | xargs | sed "s/\.\///g")
}

getDeploymentTemplates () {
  _searchPath=${1}
   if [ -z "${_searchPath}" ]; then
    echo -e \\n"getDeploymentTemplates; Missing parameter!"\\n
    exit 1
  fi

  echo $(find ${_searchPath} -regex "^.*\.\(json\|yaml\|yml\)" -exec grep -l "DeploymentConfig\|Route" '{}' \; | xargs | sed "s/\.\///g")
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

  _jenkinsFile_FullName=${_jenkinsFilePath##*/}
  _jenkinsFile_Name=${_jenkinsFilePath%.*}
  if [ -z "${_jenkinsFile_Name}" ]; then
    echo ${_jenkinsFile_FullName}
  else
    echo ${_jenkinsFile_Name}
  fi
}

isBuildConfig() {
  _template=${1}
  if [ -z "${_template}" ]; then
    echo -e \\n"isBuildConfig; Missing parameter!"\\n
    exit 1
  fi

  _isBuildConfig=$( grep -l "BuildConfig\|\"ImageStream\"\|kind:.ImageStream$" ${_template} )
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
    if [ ! -z "${PROFILE}" ]; then
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
  _pods=${@}
  if [ -z "${_pods}" ]; then
    echo -e \\n"recyclePods; Missing parameter!  You must specify the name of at least one pod."\\n
    exit 1
  fi

  switchProject
  exitOnError

  scaleDown ${_pods}
  printAndWait "Wait for all of the pods (${_pods}) to scale down completely before continuing."
  scaleUp ${_pods}
}

scaleUp() {
  _pods=${@}
  if [ -z "${_pods}" ]; then
    echo -e \\n"scaleUp; Missing parameter!  You must specify the name of at least one pod."\\n
    exit 1
  fi

  for _pod in ${_pods}; do
    scaleDeployment ${_pod} 1
  done  
}

scaleDown() {
  _pods=${@}
  if [ -z "${_pods}" ]; then
    echo -e \\n"scaleDown; Missing parameter!  You must specify the name of at least one pod."\\n
    exit 1
  fi

  for _pod in ${_pods}; do
    scaleDeployment ${_pod}
  done  
}

scaleDeployment() {
  _deplymentConfigName=${1}
  _numReplicas=${2:-0}
  if [ -z "${_deplymentConfigName}" ] || [ -z "${_numReplicas}" ]; then
    echo -e \\n"scaleDeployment; Missing parameter!  You must specify the name of at least one pod."\\n
    exit 1
  fi

  oc scale --replicas=${_numReplicas} dc ${_deplymentConfigName}
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

  runInContainer.sh "${_podName}" "${_cmd}"
}

switchProject() {
  _projectName=${1:-${PROJECT_NAMESPACE}-${DEPLOYMENT_ENV_NAME}}
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
    oc get dc | awk '{if(NR>1)print $1}'
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

deployConfigs() {
  _configFiles=$(getConfigFiles ${@})
  for configFile in ${_configFiles}; do
    oc ${OC_ACTION} -f ${configFile}
    exitOnError
  done
}

runInContainer() {
  # This is a quite version of runInContainer.sh
  _podName=${1}
  _command=${2}
  _podIndex=${3:-0}
  if [ -z "${_podName}" ] || [ -z "${_command}" ]; then
    echo -e \\n"runInContainer; Missing parameter!"\\n
    exit 1
  fi

  # Get name of a currently deployed pod by label and index
  _podInstanceName=$(getPodByName.sh "${_podName}" "${_podIndex}")
  if [ ! -z "${_podInstanceName}" ]; then
    oc exec "${_podInstanceName}" -- bash -c "${_command:-echo Hello}"
  fi
}

runInContainerInteractively() {
  _podName=${1}
  _command=${2:-echo Hello}
  if [ -z "${_podName}" ] || [ -z "${_command}" ]; then
    echo -e \\n"runInContainerInteractively; Missing parameter!"\\n
    exit 1
  fi

  _podInstanceName=$(getPodByName.sh ${_podName})
  exitOnError

  echo
  echo "Executing command on ${_podInstanceName}:"
  echo -e "\t${_command}"
  echo

  oc exec -i "${_podInstanceName}" -- bash -c "${_command}"
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
  runInContainer.sh \
  ${_databasePodName} \
  'psql -ac "DROP DATABASE \"${POSTGRESQL_DATABASE}\";"'

  runInContainer.sh \
  ${_databasePodName} \
  'psql -ac "CREATE DATABASE \"${POSTGRESQL_DATABASE}\";"'

  runInContainer.sh \
  ${_databasePodName} \
  'psql -ac "GRANT ALL ON DATABASE \"${POSTGRESQL_DATABASE}\" TO \"${POSTGRESQL_USER}\";"'
  echo "============================================================================"
  echo

  echo "============================================================================="
  echo "Listing databases ..."
  echo "-----------------------------------------------------------------------------"
  runInContainer.sh \
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
    _apiPodName=${1}
    _dbPodName=${2}
    if [ -z "${_apiPodName}" ] || [ -z "${_dbPodName}" ]; then
      echo -e \\n"dropAndRecreateDatabaseWithMigrations; Missing parameter!"\\n
      exit 1
    fi

    scaleDown ${_apiPodName}
    exitOnError

    printAndWait "Wait for the ${_apiPodName} pod to completely shut down before continuing."

    dropAndRecreatePostgreSqlDatabase ${_dbPodName}
    exitOnError

    scaleUp ${_apiPodName}
    exitOnError

    printAndWait "Wait for the ${_apiPodName} pod to completely start up and ensure it has finished running the database migrations before continuing."
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

  switchProject
  exitOnError

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