# K8s Workload Onboarding (roles under a cluster's JWT backend)

## Introduction

This documentation will provide guidance for how to give a workload running inside an onboarded
cluster (see the `k8s-cluster-onboarding/` folder) access to secrets in your APM's Vault namespace. Each entry
creates one JWT auth role under that cluster's `auth/jwt/<name>` backend, plus one policy granting
read on exactly the KV secret paths you list - and attaches that policy to the role's tokens.

## Prerequisites

* __The cluster is already onboarded__
    * Its `cluster_name` (from a `k8s-cluster-onboarding/*.yaml`) is what `cluster` references here
    * Creating a workload entry for a cluster with no backend fails the run - onboard the
      cluster first, or in the same commit (ordering within a run is handled for you)
* __The KV secret paths you list exist or will exist__
    * They come from the `kv/` folder or are written directly; this folder only grants access

## Steps to Perform

1. Within this `k8s-workload-onboarding` folder, create a `<workload_name>.yaml` file defining
   the workload
    * The file name, the top-level yaml key, the Vault role name, and (by default) the cluster
      service-account name are all the workload name - one identity, named once
    * The role is created as `auth/jwt/<cluster>/roles/<workload_name>`, and the generated policy
      is named `<cluster>-<workload_name>`
    * A role that trusts anything with the right audience is dangerous - always set
      `bound_audiences` so only tokens your workload's cluster actually issues may log in; the
      service-account bound comes from `k8s_namespace` + `k8s_service_account_name`

__For a workload on an AWS EKS cluster (IRSA-style projected token):__
```yaml
payments-api: # The entry label - also this file's name
    workload_name: payments-api # The Vault role name (required)
    cluster: eks-prod # Must match a `cluster_name` from the k8s-cluster-onboarding/ folder
    k8s_namespace: payments # The namespace the workload's service account lives in
    # k8s_service_account_name: payments-api # Optional - defaults to the workload name
    bound_audiences: ["vault-eks-prod"] # The audience the projected token carries
    vault_secret_paths: [
        "payments/*"
    ] # Read access to secret/data/payments/* and secret/metadata/payments/*
    token_ttl: 900
```

__For a workload on an on-prem OpenShift cluster:__
```yaml
reporting:
    cluster: openshift-onprem
    workload_name: reporting
    k8s_namespace: reporting
    bound_audiences: ["vault"]
    vault_secret_paths: [
        "reporting/config",
        "reporting/credentials"
    ]
```

## Required and optional arguments

* `workload_name` - __required__ - the Vault role name, the default
  service-account name, and the base of the generated policy name; lowercase alphanumeric/hyphen.
  The top-level yaml key (and the file name) is only the entry label. Renaming the yaml key
  alone never recreates anything in Vault - rename `workload_name` only when you intend to
  replace the role
* `cluster` - __required__ - the `name` of the onboarded cluster whose backend the role lives on
* `k8s_namespace` - __required__ - the cluster namespace the workload's service account runs in;
  combined with the service-account name it produces the token bound
  (`system:serviceaccount:<namespace>:<service-account>`)
* `vault_secret_paths` - __required__ - the KV paths (relative to the `secret/` mount) the
  workload may read; a trailing `*` glob is allowed

Everything else is optional:

* `k8s_service_account_name` - if the service account is named differently from the workload
* `bound_audiences` - the audience(s) the projected token carries
* `token_ttl`, `token_max_ttl`
* `extra_token_policies` - additional existing policies to attach beyond the generated one
  (e.g. one you defined in `policies/`)

## Guardrails

* __A `(cluster, workload name)` pair may appear in exactly one entry, across all files__ - the
  module's validation rejects duplicates before a plan is generated. Vault has no
  "don't overwrite" switch on roles or policies: a duplicate would mean two entries fighting
  over the same role, so uniqueness is enforced instead. The generated policy name
  `<cluster>-<workload_name>` is derived from that same pair, so it can't collide either
* Generated policies are read-only on the paths you list - no write, delete, or sudo. The role's
  tokens carry the namespace `default` policy (lookup-self / renew-self / revoke-self - what a
  client needs to manage its own token; VSO requires it) plus the generated policy and any
  `extra_token_policies`
* The ACL policy the platform team attaches to your namespace physically cannot reach outside
  it - the guardrails here are defense-in-depth, not the security boundary

## How this folder is consumed

* Every `*.yaml` file under this folder (nested subfolders included) is decoded and merged into
  the `k8s_workloads` input of the TFE-registry-published `vault-platform-user` module
  (`vault-platform-user/vault`)
* A file ending in `.yml` is ignored - only `.yaml` files are read
* Removing an entry destroys the role and its generated policy on the next run
* Committing to `main` triggers the workspace's run, and auto-apply means the role lands without
  a manual approval

## FAQ

* _How does the workload log in?_
    * `vault write auth/jwt/<cluster>/login role=<workload_name> jwt=<token>` where `<token>` is the
      service-account token projected into the pod (or the cloud IAM token, for cluster-level
      identities). With the Vault Secrets Operator, configure its VaultAuth method to do this
      for you
* _Can two workloads share one role?_
    * Yes - one entry's service-account bound covers exactly one service account, but the role
      only cares about the token's claims: give genuinely different workloads their own entries
      (a workload name per service account keeps the mapping obvious)
* _Can I add write access to secrets?_
    * Not through this folder - it grants read only. A policy with wider capabilities comes from
      `policies/`, attached via `extra_token_policies`, and stays subject to that folder's
      guardrails
