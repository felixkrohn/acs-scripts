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

echo "creating API token for gitops"
# no jq... #TOKEN="$(curl -sk -X POST -u admin:$PASSWORD https://${APIURL}/v1/apitokens/generate -d '{"name":"rhacs-gitops","role":null,"roles":["Continuous Integration"]}'| jq -r .token)"
TOKEN="$(curl -sk -X POST -u "admin:$PASSWORD" -H "Content-Type: application/json" --data '{"name":"rhacs-gitops","role":null,"roles":["Continuous Integration"]}' https://central/v1/apitokens/generate | python3 -c "import sys, json; print(json.load(sys.stdin)['token'], end = '')" | base64 -w0)"
echo "writing new token to secret gitops-api-token"
[ -n "${TOKEN}" ] && oc -n "${NAMESPACE}" patch secret gitops-api-token --type='json' -p='[{"op" : "add" ,"path" : "/data/token" ,"value" : "'"${TOKEN}"'"}]'
