#!/usr/bin/env bash
# pre-flight checks
[ -z "${CENTRAL}" ] && CENTRAL="https://central"
[ -z "${CLUSTERNAME}" ] && echo "CLUSTERNAME not set ($CLUSTERNAME), exiting" && exit 1
if [ -z "${PASSWORD}" ]; then
    echo "please verify that PASSWORD is set!"
    exit 1
fi

# Wait for central to be ready
attempt_counter=0
max_attempts=20
echo "Waiting for central to be available..."
until $(curl -k --output /dev/null --silent --head --fail ${CENTRAL}); do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
      echo "Max attempts reached"
      exit 1
    fi
    printf '.'
    attempt_counter=$(($attempt_counter+1))
    echo "Made attempt $attempt_counter, waiting..."
    sleep 10
done

echo "creating company-developer permission set and assigning it to company-developer default base role"

PS_ID="$(curl -k -u "admin:$PASSWORD" -X POST ${CENTRAL}/v1/permissionsets -H 'Content-Type: application/json' --data-raw '{"id":"","name":"company-developer","description":"Basic application-centric readonly access","resourceToAccess":{"Access":"NO_ACCESS","Administration":"NO_ACCESS","Alert":"READ_ACCESS","AllComments":"NO_ACCESS","CVE":"NO_ACCESS","Cluster":"READ_ACCESS","Compliance":"READ_ACCESS","ComplianceRuns":"NO_ACCESS","Config":"READ_ACCESS","DebugLogs":"NO_ACCESS","Deployment":"READ_ACCESS","DeploymentExtension":"READ_ACCESS","Detection":"READ_ACCESS","Image":"READ_ACCESS","Integration":"NO_ACCESS","K8sRole":"READ_ACCESS","K8sRoleBinding":"READ_ACCESS","K8sSubject":"READ_ACCESS","Namespace":"READ_ACCESS","NetworkGraph":"READ_ACCESS","NetworkGraphConfig":"NO_ACCESS","NetworkPolicy":"READ_ACCESS","Node":"READ_ACCESS","Policy":"READ_ACCESS","ProbeUpload":"NO_ACCESS","Role":"NO_ACCESS","ScannerBundle":"NO_ACCESS","ScannerDefinitions":"NO_ACCESS","Secret":"READ_ACCESS","SensorUpgradeConfig":"NO_ACCESS","ServiceAccount":"READ_ACCESS","ServiceIdentity":"NO_ACCESS","VulnerabilityManagementApprovals":"NO_ACCESS","VulnerabilityManagementRequests":"NO_ACCESS","VulnerabilityReports":"NO_ACCESS","WatchedImage":"NO_ACCESS","WorkflowAdministration":"NO_ACCESS"}}' | jq -r .id )"
echo "creating company-developer role with permission set ${PS_ID}"
response="$(curl -s -k -u "admin:$PASSWORD" -X POST "${CENTRAL}/v1/roles/company-developer" -H "Content-Type: application/json" --data-raw '{"name":"company-developer","resourceToAccess":{},"description":"base role for company-developer","permissionSetId":"'${PS_ID}'","accessScopeId":"io.stackrox.authz.accessscope.unrestricted"}')"
if [[ "$response" != "{}" ]] ; then
  echo "error while creating company-developer role with permission set ${permsetid} on ${CENTRAL} using Data: ${DATA}"
  exit 1
fi


echo "Configuring OpenShift OAuth Provider"

echo "Test if OpenShift OAuth Provider already exists"

response=$(curl -s -k -u "admin:$PASSWORD" ${CENTRAL}/v1/authProviders?name=${CLUSTERNAME} | python3 -c "import sys, json; print(json.load(sys.stdin)['authProviders'], end = '')")

if [[ "$response" != "[]" ]] ; then
  echo "${CLUSTERNAME} Provider already exists, exiting"
  exit 0
fi

ROUTE="$(oc  -n "${NAMESPACE}" get route central -ojsonpath='{.spec.host}')"

export DATA='{"id":"","name":"'${CLUSTERNAME}'","type":"openshift","config":{},"uiEndpoint":"'"${ROUTE}"'","enabled":true,"active":true}'
echo "Creating openshift oauth provider: ${DATA}"
authid=$(curl -s -k -X POST -u "admin:$PASSWORD" -H "Content-Type: application/json" --data "${DATA}" "${CENTRAL}"/v1/authProviders | python3 -c "import sys, json; print(json.load(sys.stdin)['id'], end = '')")
echo "Authentication Provider created with id ${authid}"

echo "Updating access role rules for team-cluster-admins and company-developers"
export DATA='{"previous_groups":[],"required_groups":[{"roleName":"Admin","props":{"authProviderId":"'${authid}'","key":"groups","value":"team-cluster-admins"}},{"roleName":"Analyst","props":{"authProviderId":"'${authid}'","key":"groups","value":"team-cluster-readers"}},{"roleName":"company-developer","props":{"authProviderId":"'${authid}'","key":"userid","value":"*","id":""}},{"props":{"authProviderId":"'${authid}'"},"roleName":"None"}]}'
response="$(curl -s -k -X POST -u "admin:$PASSWORD" -H "Content-Type: application/json" --data "${DATA}" "${CENTRAL}"/v1/groupsbatch)"
if [[ "$response" != "{}" ]] ; then
  echo "error while updating access role rules for team-cluster-admins and company-developers on ${CENTRAL} using Data: ${DATA}"
  exit 1
fi

