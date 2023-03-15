# what is this?
* a (partial) kustomize overlay
* containing some additional scripts to manage ACS resources
* see the files in bin/ for detailed explanations what they do
* As I don't like central's default passthrough route and TLS-cert, we use a reencrypt route with a [service-signing-service-cert](https://docs.openshift.com/container-platform/4.12/security/certificates/service-serving-certificate.html)

# really, what is this?
* some useless stuff, and two interesting scripts:
  * `write-policy-configmap-files.sh` will export the policies in the current ACS install into files as ConfigMaps, which can then be synced into the cluster via gitops approach
  * `load-policies.sh` will run periodically in the cluster through a cronjob, and load the CMs containing policies, extract the policy, and push it into ACS.

# Does it work?
* for me, yes. YMMV.
