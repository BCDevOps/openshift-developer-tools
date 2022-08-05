# ====================================================================================
# getDids
#   - See getDids.sh for use.
# ------------------------------------------------------------------------------------
# This function scans through accessible (based on user access) OCP projects to 
# discover the DIDs associated to Hyperledger Indy and Aries project components.
# It then scans the Sovrin networks for additional information regarding the
# DID and it's most recent activity.
# The data is then saved to a csv file as well as being output to the console.
#
# Data Collected:
# ---------------
# Project Name:
#   - The name (license plate) of the OCP project in which the DID was found.
#
# Name:
#   - The resource (component) name associated with the DID.
#
# DID:
#   - The DID.
#
# Ledger:
#   - The ledger on which the DID resides.  Only the Sovrin networks are scanned.
#   - Therefore "Unknown" means the DID resides on a ledger other than one of
#     the Sovrin networks.  This could be any of the BCovrin or CANdy ledgers.
#
# Role:
#   - The role assigned to the DID.  Only the Sovrin networks are scanned.
#
# Last Used Date:
#   - The date associated to the last txn written to the ledger by the DID.
#
# Last Used For:
#   - The last written txn type.
# ====================================================================================
function getDids()
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

    # von-network needed to convert Seeds into DIDs
    if [ ! -d ./von-network ]; then
      echoWarning "Cloning von-network to $(pwd)/von-network ..."
      git clone --depth 1 https://github.com/bcgov/von-network.git ./von-network
    fi

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

    echo
    echo
    for project in ${projects}; do
      echo -e "\e[1A\e[KScanning project '${project}' ..."

      # Get project name
      projectDisplayName=$(oc get project ${project} -o json | jq --raw-output '.metadata.annotations."openshift.io/display-name"')

      # Get a list of seeds in each environment ...
      seeds=$(oc -n ${project} --context=${context} get secret --template '{{ range $item := .items }}{{if $item.data.seed}}{{ printf "%s,%s\n" $item.metadata.name $item.data.seed}}{{end}}{{end}}')

      if [ ! -z "${seeds}" ]; then
        # Decode the Seeds into DIDs
        for item in ${seeds}; do
          seed=$(echo ${item##*,} | openssl base64 -d)
          pushd ./von-network >/dev/null
          did=$(./manage generatedid ${seed} 2>/dev/null | sed -n 's~^DID: \(.*\)$~\1~p')
          popd >/dev/null

          # Scan for the DID on the Sovrin Ledgers
          ledgers="SOVRIN_STAGINGNET SOVRIN_MAINNET SOVRIN_BUILDERNET"
          for ledger in ${ledgers}; do
            result=$(curl -s "https://indyscan.io/api/networks/${ledger}/ledgers/domain/txs?filterTxNames=%5B%22NYM%22%5D&format=expansion&sortFromRecent=true&search=${did}")

            jqQuery="[.[].idata.txn.data | select(.dest==\"${did}\")][0]"
            parsedResult=$(echo "${result}" | jq --raw-output "${jqQuery}")
            if [ ! -z "${parsedResult}" ] && [ "${parsedResult}" != "null" ]; then
              break;
            fi
          done

          if [ ! -z "${parsedResult}" ] && [ "${parsedResult}" != "null" ]; then
            role=$(echo "${parsedResult}" | jq --raw-output '.role')
            if [ ${role} == "101" ]; then
              role="Endorser"
            fi

            # Get last used date from the most recent txn associated with the DID
            result=$(curl -s "https://indyscan.io/api/networks/${ledger}/ledgers/domain/txs?size=1&format=expansion&sortFromRecent=true&search=${did}")
            lastUsedDate=$(echo "${result}" | jq --raw-output '.[0].idata.txnMetadata.txnTime')
            lastUsedFor=$(echo "${result}" | jq --raw-output '.[0].idata.txn.typeName')
          else
            role="Unknown"
            ledger="Unknown"
            lastUsedDate="Unknown"
            lastUsedFor="Unknown"
          fi

          didList+="${project},${projectDisplayName},${item%%,*},${did},${ledger},${role},${lastUsedDate},${lastUsedFor}\n"
        done
      fi
    done

    if [ ! -z "${filter}" ]; then
      echo -e "\e[1A\e[KFiltering did list on '${filter}' ..."
      unset filteredList
      didListToFilter=$(echo "${didList}" | sed 's~\\n~\n~g')
      for item in ${didListToFilter}; do
        filteredDid=$(echo "${item}" | grep "${filter}")
        if [ ! -z "${filteredDid}" ]; then
          filteredList+="${filteredDid}\n"
        fi
      done
      didList="${filteredList}"
    fi

    echo -e "\e[1A\e[K"
    didList=$(echo "${didList}" | sed 's~\\n~\n~g')
    itemCount=$(echo "${didList}" | wc -l)
    result="$(echo -e "PROJECT:,DISPLAY NAME:,NAME:,DID:,LEDGER:,ROLE:,LAST USED DATE:,LAST USED FOR:\n${didList}")"
    echoWarning "Writing results to $(pwd)/DID-List.csv ...\n"
    echo "${result}" > DID-List.csv
    echoWarning "Results (${itemCount}):"
    echo "${result}" | column -t -s ,

    # Clean-up von-network
    if [ -d ./von-network ]; then
      echoWarning \\n"Removing von-network from $(pwd)/von-network ..."
      rm -rf ./von-network
    fi
  )
}
