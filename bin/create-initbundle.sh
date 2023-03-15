#!/usr/bin/env bash

# Wait for central to be ready
attempt_counter=0
max_attempts=20
echo "Waiting for central to be available..."
until $(curl -k --output /dev/null --silent --head --fail https://central); do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
      echo "Max attempts reached"
      exit 1
    fi
    printf '.'
    attempt_counter=$(($attempt_counter+1))
    echo "Made attempt $attempt_counter, waiting..."
    sleep 10
done

initbundle="{ \"name\": \"${CLUSTERNAME}\" }"
echo "Creating new init-bundle with: ${initbundle}"
response="$(curl -k -s -X POST -u "admin:$PASSWORD" --data "${initbundle}" https://central/v1/cluster-init/init-bundles)"
error="$(echo "${response}" | python3 -c "import sys, json; print(json.load(sys.stdin)['error'], end = '')" 2>/dev/null )"
if [[ -z "${error}" ]]
then
    # helmValuesBundle="$(echo "${response}" | python3 -c "import sys, json; print(json.load(sys.stdin)['helmValuesBundle'], end = '')")"
    kubectlBundle="$(echo "${response}" | python3 -c "import sys, json; print(json.load(sys.stdin)['kubectlBundle'], end = '')")"
    if [ -n "${kubectlBundle}" ]
    then
        echo "writing kubectlBundle content to secrets"
        echo "${kubectlBundle}" | base64 -d | oc replace -f -
    else
        echo "Error in response: no kubectlBundle"
        echo "---------------------------------------------"
        echo "${response}"
        echo "---------------------------------------------"
        exit 2
    fi
else
    echo "Error: ${error}"
    exit 0 # log message but exit quietly - in case the job has to be run a second time because the state of the first run was lost.
fi

if [[ "$response" = "[]" ]] ; then
  echo "${CLUSTERNAME} Provider already exists, exiting"
  exit 0
fi

exit 0
