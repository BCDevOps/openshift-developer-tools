#!/bin/bash

OCTOOLSBIN=$(dirname $0)

usage() {
  cat <<-EOF
  Tags the project's images

  Usage:
    ${0##*/} [options] -s <source_tag> -t <destination_tag>

  Options:
  ========
    -s the source tag name
    -t the tag to apply
EOF
}

# =================================================================================================================
# Process the local command line arguments and pass everything else along.
# - The 'getopts' options string must start with ':' for this to work.
# -----------------------------------------------------------------------------------------------------------------
while [ ${OPTIND} -le $# ]; do
  if getopts :s:t: FLAG; then
    case ${FLAG} in
      # List of local options:
      s) export SOURCE_TAG=$OPTARG ;;
      t) export DESTINATION_TAG=$OPTARG ;;

      # Pass unrecognized options ...
      \?) pass+=" -${OPTARG}" ;;
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

if [ -z "${SOURCE_TAG}" ] || [ -z "${DESTINATION_TAG}" ]; then
  echo -e \\n"Missing parameters - source or destination tag"\\n
  usage
fi
# ==============================================================================

echo -e \\n"Tagging images for ${DESTINATION_TAG} environment deployment ..."
for image in ${images}; do
  echo -e \\n"Tagging ${image}:${SOURCE_TAG} as ${image}:${DESTINATION_TAG} ..."
  oc tag ${image}:${SOURCE_TAG} ${image}:${DESTINATION_TAG} -n ${TOOLS}
  exitOnError
done
