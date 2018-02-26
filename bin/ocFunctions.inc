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

exitOnError () {
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
  rtnVal=$(oc whoami -c |  grep '/127-0\|/10-0')
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

assignRole (){
  role=$1
  user=$2
  project=$3

  echo "Assigning role [${role}], to user [${user}], in project [${project}] ..."
  oc policy add-role-to-user ${role} ${user} -n ${project}
  echo
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

  # Fancy sed handling below to convert parameters output to param file format
  # - Delete the first line of the oc process output
  # - Put "XXXX" in front of the parameter default value
  # - Remove all whitespace before the XXXX and change XXXX to =
  # - Use _commentFilter to add (or not) a "#" in front of each line; "#" comments it out the line
  #  - i.e. set _commentFilter="sed s/^/#/" to comment out the line

  # 1. Remove the headers (the first line) from the file.
  # 2. Place 'XXXX' in front of the start of the value column
  # 3. Replace ALL of the text between the Key and the Value with '='.  Having the 'XXXX' helps with this.
  # 4. + Apply additional filters to the parameters
  oc process --parameters --filename=${_template} | \
    sed '1d' | \
    sed 's~\([^ ]*$\)~XXXX\1~' | \
    sed 's~\s.*XXXX~=~' | \
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
 echo $(find . -name "*json" -exec grep -l "DeploymentConfig\|BuildConfig\|Route\|\"ImageStream\"" '{}' \; | sed "s/.json//" | xargs | sed "s/\.\///g")
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

  _isBuildConfig=$( grep -l "BuildConfig\|\"ImageStream\"" ${_template} )
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
    _name=$(getJenkinsFileName ${_jenkinsFile})
    _directory=$(getDirectory ${_jenkinsFile})

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
