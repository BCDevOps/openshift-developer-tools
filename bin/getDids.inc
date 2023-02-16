#!/bin/bash
UNKNOWN="Unknown"
QUERY_TIMEOUT=30
BCOVRIN_QUERY_TIMEOUT=600
TXN_TYPES="
0=NODE
1=NYM
3=GET_TXN
4=TXN_AUTHOR_AGREEMENT
5=TXN_AUTHOR_AGREEMENT_AML
6=GET_TXN_AUTHOR_AGREEMENT
7=GET_TXN_AUTHOR_AGREEMENT_AML
8=DISABLE_ALL_TXN_AUTHR_AGRMTS
100=ATTRIB
101=SCHEMA
102=CRED_DEF
103=DISCLO
104=GET_ATTR
105=GET_NYM
107=GET_SCHEMA
108=GET_CLAIM_DEF
109=POOL_UPGRADE
110=NODE_UPGRADE
111=POOL_CONFIG
112=CHANGE_KEY
113=REVOC_REG_DEF
114=REVOC_REG_ENTRY
115=GET_REVOC_REG_DEF
116=GET_REVOC_REG
117=GET_REVOC_REG_DELTA
118=POOL_RESTART
119=VALIDATOR_INFO
120=AUTH_RULE
121=GET_AUTH_RULE
122=AUTH_RULES
"

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

    initTxnMap

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

          scanLedgers "${did}"

          didList+="${project},${projectDisplayName},${item%%,*},${did},${ledger},${role},${lastUsedDate},${lastUsedFor}\n"
        done
      fi
    done

    # ====================================================================================================================
    # For testing and troubleshooting
    # --------------------------------------------------------------------------------------------------------------------
    # Sovrin TestNet
    # did="RznYFPVhHpYZgsn4Hu3StV"
    # # dev.bcovrin
    # did="6tGCSqhLKu31BCKRrf7nGe"
    # # test.bcovrin
    # did="F5xxSw8bAKBWjNvC43dMbm"
    # did="NEYQZjF5bs1tTRbCVs5w7Q"
    # scanLedgers "${did}"
    # didList+="${project},${projectDisplayName},${item%%,*},${did},${ledger},${role},${lastUsedDate},${lastUsedFor}\n"
    # ====================================================================================================================

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

declare -A txnMap
function initTxnMap() {
  for txn_type in ${TXN_TYPES}; do
    key=${txn_type%%=*}
    value=${txn_type#*=}
    txnMap[${key}]=${value}
  done
}

# ToDo:
# - The following functions rely on global variables so there is potential for variables
#   to get overwritten inadvertently with the wrong data.  This should be addressed,
#   however at this point things are working as expected.
function scanLedgers() {
  local did=${1}
  ledger="${UNKNOWN}"

  if isLedgerUnknow ${ledger}; then
    scanSovrinLedgers "${did}"
  fi

  if isLedgerUnknow ${ledger}; then
    scanCandyLedgers "${did}"
  fi

  if isLedgerUnknow ${ledger}; then
    scanBCovrinLedgers "${did}"
  fi
}

function scanSovrinLedgers() {
  local did=${1}
  local baseUrl="https://indyscan.io"

  # Scan for the DID on the Sovrin Ledgers
  ledgers="SOVRIN_STAGINGNET SOVRIN_MAINNET SOVRIN_BUILDERNET"
  for ledger in ${ledgers}; do
    scanLedger "${did}" "${ledger}" "${baseUrl}"
    if isNotNullOrEmpty "${parsedResult}"; then
      break;
    fi
  done
}

function scanCandyLedgers() {
  local did=${1}
  local baseUrl="https://candyscan.idlab.org"

  # Scan for the DID on the CANdy Ledgers
  ledgers="CANDY_DEV CANDY_TEST CANDY_PROD"
  for ledger in ${ledgers}; do
    scanLedger "${did}" "${ledger}" "${baseUrl}"
    if isNotNullOrEmpty "${parsedResult}"; then
      break;
    fi
  done
}

function scanBCovrinLedgers() {
  local did=${1}

  # Scan for the DID on the BCovrin Ledgers
  # Scan BCovrin Test last, because it takes longer
  ledgers="dev.bcovrin prod.bcovrin test.bcovrin"
  for ledger in ${ledgers}; do
    local baseUrl="http://${ledger}.vonx.io"
    scanBCovrin "${did}" "${ledger}" "${baseUrl}"
    if isNotNullOrEmpty "${parsedResult}"; then
      break;
    fi
  done
}

function scanBCovrin() {
  local did=${1}
  ledger=${2}
  local baseUrl=${3}

  echo -e "\e[1A\e[KScanning ${ledger} for ${did} ..."
  result=$(curl -G -m ${BCOVRIN_QUERY_TIMEOUT} -s "${baseUrl}/ledger/domain" \
           -H 'Cache-Control: no-cache, no-store' \
           -H "accept: application/json" \
           --data-urlencode "page=1" \
           --data-urlencode "page_size=10" \
           --data-urlencode "type=1" \
           --data-urlencode "query=${did}")
  getBCovrinData "${did}" "${result}"

  if isNotNullOrEmpty "${parsedResult}"; then
    getRole "${parsedResult}"
    # Get last used date from the most recent txn associated with the DID
    result=$(curl -G -m ${BCOVRIN_QUERY_TIMEOUT} -s "${baseUrl}/ledger/domain" \
            -H "accept: application/json" \
            --data-urlencode "page=1" \
            --data-urlencode "page_size=100" \
            --data-urlencode "type=" \
            --data-urlencode "query=${did}")
    getLastUsedInfo_BCovrin "${result}"
  else
    role="${UNKNOWN}"
    ledger="${UNKNOWN}"
    lastUsedDate="${UNKNOWN}"
    lastUsedFor="${UNKNOWN}"
  fi
}

function scanLedger() {
  local did=${1}
  ledger=${2}
  local baseUrl=${3}

  echo -e "\e[1A\e[KScanning ${ledger} for ${did} ..."
  result=$(curl -G -m ${QUERY_TIMEOUT} -s "${baseUrl}/api/networks/${ledger}/ledgers/domain/txs" \
          -H "accept: application/json" \
          --data-urlencode "filterTxNames=[\"NYM\"]" \
          --data-urlencode "format=expansion" \
          --data-urlencode "sortFromRecent=true" \
          --data-urlencode "search=${did}")
  getData "${did}" "${result}"

  if isNotNullOrEmpty "${parsedResult}"; then
    getRole "${parsedResult}"
    # Get last used date from the most recent txn associated with the DID
    result=$(curl -G -m ${QUERY_TIMEOUT} -s "${baseUrl}/api/networks/${ledger}/ledgers/domain/txs" \
            -H "accept: application/json" \
            --data-urlencode "size=1" \
            --data-urlencode "format=expansion" \
            --data-urlencode "sortFromRecent=true" \
            --data-urlencode "search=${did}")
    getLastUsedInfo "${result}"
  else
    role="${UNKNOWN}"
    ledger="${UNKNOWN}"
    lastUsedDate="${UNKNOWN}"
    lastUsedFor="${UNKNOWN}"
  fi
}

function getData() {
  local did=${1}
  local result=${2}
  jqQuery="[.[].idata.txn.data | select(.dest==\"${did}\")][0]"
  parsedResult=$(echo "${result}" | jq --raw-output "${jqQuery}")
}

function getBCovrinData() {
  local did=${1}
  local result=${2}
  jqQuery="[.results[].txn.data | select(.dest==\"${did}\")][0]"
  parsedResult=$(echo "${result}" | jq --raw-output "${jqQuery}")
}

function getRole() {
  local parsedResult=${1}
  role=$(echo "${parsedResult}" | jq --raw-output '.role')
  if [ ${role} == "101" ]; then
    role="Endorser"
  fi
}

function getLastUsedInfo() {
  local result=${1}
  lastUsedDate=$(echo "${result}" | jq --raw-output '.[0].idata.txnMetadata.txnTime')
  lastUsedFor=$(echo "${result}" | jq --raw-output '.[0].idata.txn.typeName')
}

function getLastUsedInfo_BCovrin() {
  local result=${1}

  lastUsedTimestamp=$(echo "${result}" | jq --raw-output '.results[-1].txnMetadata.txnTime')
  lastUsedDate=$(date -d @${lastUsedTimestamp} --utc +%Y-%m-%dT%T.%3NZ)
  lastUsedForTxnTypeCd=$(echo "${result}" | jq --raw-output '.results[-1].txn.type')
  lastUsedFor=${txnMap[${lastUsedForTxnTypeCd}]}
}

function isNotNullOrEmpty() {
  local parsedResult=${1}
  if [ ! -z "${parsedResult}" ] && [ "${parsedResult}" != "null" ]; then
    return 0
  else
    return 1
  fi
}

function isLedgerUnknow() {
  local leger=${1}
  if [ "${leger}" == "${UNKNOWN}" ]; then
    return 0
  else
    return 1
  fi
}