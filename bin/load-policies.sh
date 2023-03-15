#!/bin/bash

# This script queries for CMs with argocd-auto-sync=true label in $NAMESPACE,
# takes the CM's data as policy and uploads it to rhacs. It is meant to be
# used to manage the policies in git, and upload them to rhacs whenever a
# change is applied through argoCD.

[ -z "${NAMESPACE}" ] && export NAMESPACE="company-rhacs"	# should be set by env
ROX_ENDPOINT="https://central-tls"

# Wait for central to be ready
attempt_counter=0
max_attempts=20
echo "Waiting for central to be available..."
until $(curl -k --output /dev/null --silent --head --fail ${ROX_ENDPOINT} ); do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
      echo "Max attempts reached"
      exit 1
    fi
    printf '.'
    attempt_counter=$(($attempt_counter+1))
    echo "Made attempt $attempt_counter, waiting..."
    sleep 10
done

for cm in $(oc -n ${NAMESPACE} get cm -l argocd-auto-sync=true -oNAME)
do
  echo "pushing content from CM ${cm} to ${ROX_ENDPOINT}"
  oc -n ${NAMESPACE} get ${cm} -o jsonpath="{ .data.policy }" | curl -sk -X PUT -u "admin:$PASSWORD" -H "Content-Type: application/json" --data-binary @- "${ROX_ENDPOINT}/v1/policies/${cm/configmap\/}"
  if [ "${?}" == "0" ]
  then
    echo "result OK."
  else
    echo "ERROR: $?"
  fi
done

# TODO: 
#   - prune policies present on rhacs but not in git (only if they're not default policies)
