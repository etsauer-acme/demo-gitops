# Demo Cluster GitOps

This repo represents a simple GitOps configuration for a new demo OpenShift cluster (currently v4.22), intended for a small team to use to collaborate on experiments. It provides the following config:

- A GitHub Oauth identity provider
- an OpenShift Dev Spaces deployment

1. Provision a new cluster in the product demo system
1. Create a GitHub Oauth App for DevSpaces, and export the client id and secret to your environment.
    ```bash
    export GITHUB_OAUTH_CLIENT_ID=<client id>
    export GITHUB_OAUTH_CLIENT_SECRET=<client secret>
    ```
1. Create a GitHub Oauth App for OpenShift login, and export the client id and secret to your environment.
    ```bash
    export GITHUB_OAUTH_OPENSHIFT=<client secret>
    ```
1. Apply configs to install Dev Spaces and Pelorus
```bash
envsubst < .bootstrap/github-oauth-openshift.yaml | oc apply -f -
oc apply -f .bootstrap/argocd-*.yaml
```


```
helm install auth ./auth -f values.yaml --set github.oauthOpenShiftId=<your-id>
```