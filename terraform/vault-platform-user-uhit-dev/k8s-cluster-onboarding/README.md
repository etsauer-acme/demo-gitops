# Cluster Onboarding (JWT auth per cluster)

## Introduction

This documentation will provide guidance for how to connect an external cluster - AWS EKS, Azure
AKS, an on-prem OpenShift cluster, anything that can project a JWT - to your APM's own Vault
namespace. Each entry creates one JWT auth backend, named after the cluster, that trusts that
cluster's token issuer. Workload roles on the backend come afterwards, from the
`k8s-workloads/` folder.

## Prerequisites

* __The cluster's connection secret is already in your namespace's KV mount__
    * Write it to `clusters/<cluster_name>` - the path must match the `cluster_name` in the yaml exactly
    * This is where secret values live (e.g. `oidc_client_secret`); the yaml in this folder never
      carries secrets. Write the entry via the `kv/` folder or directly in Vault, then commit the
      yaml here
    * For a public JWKS/OIDC-discovery setup with no client secret, an entry with any placeholder
      value is fine - the folder reads the entry regardless, and unused keys are ignored
* __You know how the cluster signs its service-account tokens__
    * Either its OIDC discovery URL (most EKS/AKS/OpenShift setups) or its JWKS URL / signing keys

## Steps to Perform

1. Within this `k8s-cluster-onboarding` folder, create a `<name_you_want_for_the_entry>.yaml` file defining the
   cluster you want to onboard
    * The file name is only for your own organization - `cluster_name` is the cluster's actual
      identity: it names the auth backend (mounted at `auth/jwt/<cluster_name>`) and must match
      the KV secret path `clusters/<cluster_name>` holding its connection secret
    * The top-level keys from every file in this folder are merged together, so each entry name
      must be unique across the whole folder, and every `cluster_name` must be unique too

__For a cluster whose issuer publishes OIDC discovery (EKS, AKS, OpenShift):__
```yaml
eks-prod: # The entry label you choose
    cluster_name: eks-prod # Must match the KV secret path clusters/eks-prod
    oidc_discovery_url: https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE # The cluster's OIDC issuer URL
    oidc_client_id: vault-eks-prod # Optional - only needed if the issuer requires a confidential client
    bound_issuer: https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE # Optional - rejects tokens with any other issuer claim
    description: Production EKS cluster, us-west-2 # Optional
```

__For a cluster you reach by JWKS URL instead (no discovery endpoint):__
```yaml
openshift-onprem:
    cluster_name: openshift-onprem
    jwks_url: https://openshift.lab.example.com/oauth2/jwks # Where Vault fetches the cluster's public signing keys
    bound_issuer: https://kubernetes.default.svc # Match the iss claim OpenShift projects into tokens
```

__For a plain Kubernetes/on-prem cluster that publishes neither discovery nor JWKS (e.g. microk8s):__
```yaml
microk8s:
    cluster_name: microk8s
    jwt_validation_pubkeys: # The cluster's service-account signing PUBLIC keys - not secret
        - |
            -----BEGIN PUBLIC KEY-----
            MIIBIjANBgkq...
            -----END PUBLIC KEY-----
    bound_issuer: https://kubernetes.default.svc.cluster.local # The cluster's --service-account-issuer
```

__The matching KV entry (written via `kv/` or Vault directly, before this yaml):__
```yaml
cluster-eks-prod-connection:
    path: clusters/eks-prod # Path must equal clusters/<cluster_name> from the yaml above
    data_json: '{"oidc_client_secret": "changeme"}' # The one secret value - everything public lives in the yaml
```

The KV entry is read fresh every run (ephemerally, never stored in run state) and carries only
the genuinely sensitive value: `oidc_client_secret`, for a cluster whose OIDC issuer requires a
confidential client. Clusters on the discovery/JWKS/pubkeys paths usually need no client secret -
the entry must still exist, a placeholder is fine. Everything public - trust anchors, signing
keys - belongs in this folder's yaml, not in KV.

## Required and optional arguments

* `cluster_name` - __required__ - the cluster's identity: becomes the auth backend mount path
  `auth/jwt/<cluster_name>` and must match the KV secret path `clusters/<cluster_name>`.
  Lowercase alphanumeric/hyphen only

Everything else is optional:

* Trust configuration (public - lives here, not in KV): `oidc_discovery_url`,
  `oidc_discovery_ca_pem`, `jwks_url`, `jwks_ca_pem`, `jwt_validation_pubkeys` (list of PEM
  public keys), `bound_issuer`, `oidc_client_id`
* `oidc_client_secret_wo_version` - bump this number when you rotate the client secret in KV;
  without it a rotated value would not be picked up
* `description` - a free-text description on the auth backend

One of `oidc_discovery_url`, `jwks_url`, or `jwt_validation_pubkeys` is mandatory - Vault needs
one way to verify the cluster's signed tokens. The pubkeys path is the one for plain
Kubernetes/on-prem clusters (e.g. microk8s) that publish neither discovery nor JWKS: extract the
cluster's service-account signing public key, put it in this yaml as a PEM list, and set
`bound_issuer` to the cluster's `--service-account-issuer`.

## Guardrails

* `cluster_name` becomes part of Vault paths - lowercase alphanumeric/hyphen, max 40 chars. The backend
  always mounts under `jwt/`, so it can never collide with the platform's own shared `jwt`
  backend, which lives in the root namespace
* The auth backend exists only inside your namespace - another APM's namespace cannot see it, and
  you cannot see theirs
* Removing an entry destroys the backend *and every role under it* on the next run - take
  `k8s-workload-onboarding/` entries with it in the same commit

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into
  the `clusters` input of the TFE-registry-published `vault-platform-user` module
  (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* The client secret is fetched fresh (ephemerally) on every run - but write-only values only
  update when `oidc_client_secret_wo_version` changes, so bump it in the yaml when you rotate
* Committing to `main` triggers the workspace's run, and auto-apply means the backend lands
  without a manual approval

## FAQ

* _How does a workload in the cluster authenticate now?_
    * Through a role from the `k8s-workloads/` folder: `vault write auth/jwt/<cluster_name>/login
      role=<workload_name> jwt=<projected service-account token>`
* _Can I onboard a cluster without a connection secret?_
    * Yes - public OIDC discovery or a JWKS URL needs none. The `clusters/<name>` KV entry must
      still exist (a placeholder is fine), because the run reads it
* _What happened to "backend enablement is the platform team's job"?_
    * For the platform's shared backends, that's still true. Cluster backends are your own
      namespace's mounts - `<name>` lives and dies inside your namespace - so you manage them
      yourself from this folder
