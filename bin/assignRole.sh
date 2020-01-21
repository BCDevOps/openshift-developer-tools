#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  Assigns a role to a user in one or more projects.

  Usage: $0 [ -h -x ] -r <role> -u <user> <space delimited project list>

  OPTIONS:
  ========
    -r the role to assign; typically on of 'view', 'edit', or 'admin'
    -u the user to which the role is to be assigned
    -f read the project list from a file
    -h prints the usage for the script
    -x run the script in debug mode to see what's happening
EOF
exit 1
}
# =================================================================================================================

# =================================================================================================================
# Funtions:
# -----------------------------------------------------------------------------------------------------------------
readProjectList(){
  (
    if [ -f ${projectListFile} ]; then
      # Read in the file minus any comments ...
      echo "Reading project list from ${projectListFile} ..." >&2
      _value=$(sed '/^[[:blank:]]*#/d;s/#.*//' ${projectListFile})
    fi
    echo "${_value}"
  )
}
# =================================================================================================================

# =================================================================================================================
# Initialization:
# -----------------------------------------------------------------------------------------------------------------
# In case you wanted to check what variables were passed
# echo "flags = $*"
while getopts r:u:f:hx FLAG; do
  case $FLAG in
    r) export role=$OPTARG ;;
    u) export user=$OPTARG ;;
    f) export projectListFile=$OPTARG ;;
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
# echo Remaining arguments: $@

if [ -f ${OCTOOLSBIN}/ocFunctions.inc ]; then
  . ${OCTOOLSBIN}/ocFunctions.inc
fi

if [ ! -z "${DEBUG}" ]; then
  set -x
fi

if [ ! -z "${projectListFile}" ]; then
  projects=$(readProjectList)
else
  projects=${@}
fi

if [ -z "${role}" ] || [ -z "${user}" ] || [ -z "${projects}" ]; then
  echo -e \\n"Missing parameters - role, user, or projects."\\n
  usage
fi
# =================================================================================================================

# =================================================================================================================
# Main Script
# -----------------------------------------------------------------------------------------------------------------
for project in ${projects}; do
  assignRole "${role}" "${user}" "${project}"
  exitOnError
done
# =================================================================================================================