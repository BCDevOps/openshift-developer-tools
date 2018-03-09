#!/bin/bash

OCTOOLSBIN=$(dirname $0)

# =================================================================================================================
# Usage:
# -----------------------------------------------------------------------------------------------------------------
usage() {
  cat <<-EOF
  A wrapper tool to generate OpenShift template and pipeline parameters files for the application.

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
    h ) usage ;;
    \?) #unrecognized option - show help
      echo -e \\n"Invalid script option"\\n
      usage
      ;;
  esac
done
# =================================================================================================================

# For this to work the two scripts must accept the same set of options.
genTemplateParams.sh $@
genPipelineParams.sh $@
