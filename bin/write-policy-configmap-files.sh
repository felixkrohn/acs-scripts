#!/bin/bash

# this script can be used to initially load all policies saved in rhacs and
# store them in configmaps in YAML files, in order to sync them via argoCD

if [[ -z "${NAMESPACE}" ]]; then
  if [ -f /run/secrets/kubernetes.io/serviceaccount/namespace ]; then
    NAMESPACE="$(cat /run/secrets/kubernetes.io/serviceaccount/namespace)"
  else
    NAMESPACE="company-rhacs"
  fi
fi

if [[ -z "${ROX_ENDPOINT}" ]]; then
  if [ -d /run/secrets/kubernetes.io/ ]; then
    ROX_ENDPOINT="https://central-tls.${NAMESPACE}.svc.cluster.local"
  else
    ROX_ENDPOINT="https://$(oc  -n "${NAMESPACE}" get route central -ojsonpath='{.spec.host}')"
  fi
fi

if [[ -z "${PASSWORD}" ]]; then
  echo "no PASSWORD set, trying to obtain from secret"
  PASSWORD="$(oc -n "${NAMESPACE}" get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}')" || exit 1
fi

for uid in $( curl -sk -u "admin:${PASSWORD}" "${ROX_ENDPOINT}/v1/policies" | jq -r '.policies[].id'); do
  echo "${uid}"
  curl -sk -u "admin:${PASSWORD}" "${ROX_ENDPOINT}/v1/policies/${uid}" | jq | sed 's/"lastUpdated":.*/"lastUpdated": null,/g' > ${uid}.txt
  #(oc -n ${NAMESPACE} create cm ${uid} --dry-run=client -oyaml --from-file=policy=${uid}.txt && echo -e "  labels:\n    argocd-auto-sync: true") | oc apply -n ${NAMESPACE}
  name="$(jq -r '.name' "${uid}".txt | sed "s/\"/'/g")"
  description="$(jq -r '.description' "${uid}".txt  | sed "s/\"/'/g")"
  rationale="$(jq -r '.rationale' "${uid}".txt  | sed "s/\"/'/g")"
  remediation="$(jq -r '.remediation' "${uid}".txt  | sed "s/\"/'/g")"
  disabled="$(jq -r '.disabled' "${uid}".txt  | sed "s/\"/'/g")"

  oc -n ${NAMESPACE} create cm ${uid} --dry-run=client -oyaml --from-file=policy=${uid}.txt  > ${uid}.cm.yaml
  rm -f ${uid}.txt
  cat >> ${uid}.cm.yaml << EOF
  labels:
    argocd-auto-sync: "true"
  annotations:
    company-policy-spec/uid: "${uid}"
    company-policy-spec/name: "${name}"
    company-policy-spec/description: "${description}"
    company-policy-spec/rationale: "${rationale}"
    company-policy-spec/disabled: "${disabled}"
EOF
done

# write kustomization.yaml
echo -e "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\n\nresources:\n" > kustomization.yaml
for i in $(ls -1 | egrep '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.cm\.yaml')
do
	echo "  - ${i}"
done  >> kustomization.yaml
