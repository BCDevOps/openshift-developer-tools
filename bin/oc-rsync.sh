#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  A helper script to copy files and folder to and from pods running in OpenShift.
  Accepts the friendly or full name of a pod.

  Usage:
    ${0} [ -h -x] -s <source_path> -d <destination_path>

  OPTIONS:
  ========
    -s The source path.
    -d The destination path.

    -h prints the usage for the script
    -x run the script in debug mode to see what's happening

  Examples:
    # Copy local directory to a pod directory
    ${0} -s /home/user/source -d devpod:/src

    # Copy pod directory to a local directory
    ${0} -s devpod:/src -d /home/user/source
EOF
exit
}
# -----------------------------------------------------------------------------------------------------------------
# Funtions:
# -----------------------------------------------------------------------------------------------------------------
resolvePodPath () {
  _path=${1}
  if [ -z "${_path}" ]; then
    echo -e \\n"resolvePodPath; Missing parameter!"\\n
    exit 1
  fi
  
  if [[ ${_path} = *":"* ]]; then
    _podName=$(echo ${_path} | sed 's~\(^.*\):.*$~\1~')
    _podPath=$(echo ${_path} | sed 's~^.*:\(.*$\)~\1~')
    _podInstanceName=$(getPodByName.sh ${_podName})
    _path="${_podInstanceName}:${_podPath}"
  fi

  echo ${_path}
}
# -----------------------------------------------------------------------------------------------------------------
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
while getopts s:d:hx FLAG; do
  case $FLAG in
    s ) SOURCE=$OPTARG ;;
    d ) DESTINATION=$OPTARG ;;
    x ) export DEBUG=1 ;;
    h ) usage ;;
    \? ) #unrecognized option - show help
      echo -e \\n"Invalid script option: -${OPTARG}"\\n
      usage
      ;;
  esac
done

shift $((OPTIND-1))

if [ ! -z "${DEBUG}" ]; then
  set -x
fi

if [ -z "${SOURCE}" ] || [ -z "${DESTINATION}" ]; then
  echo -e \\n"Missing parameters ..."\\n
  usage
fi

SOURCE=$(resolvePodPath ${SOURCE})
DESTINATION=$(resolvePodPath ${DESTINATION})
# =================================================================================================================

echo "Copying ${SOURCE} to ${DESTINATION} ..."
oc rsync ${SOURCE} ${DESTINATION}