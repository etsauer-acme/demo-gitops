# Demo Cluster GitOps

This repo represents a GitOps configuration for an OpenShift cluster (v4.22+) using ArgoCD with an app-of-apps pattern.

## Structure

- `.bootstrap/` - Bootstrap manifests for installing ArgoCD and initial configuration
- `auth/` - Helm chart for GitHub OAuth identity provider configuration
- `rbac/` - Helm chart for cluster role bindings
- `argo-apps/` - App-of-apps pattern for managing all ArgoCD applications
- `terraform/` - HCP Terraform deployment roots (migrated from `zisom-hc/terraform-vault-vault-platform-*-deployment`), applied through the `team-rts-fiserv` org:
  - `terraform/vault-platform-admin/` - workspace `vault-platform-admin`: cluster-level Vault platform objects (namespaces, root policies, auth backends, per-APM namespace onboarding) on `uhit-dev-vault`
  - `terraform/vault-platform-user-uhit-dev/` - workspace `vault-platform-user-uhit-dev`: per-APM namespace `admin/uhit-dev` objects (KV secrets, AppRole/JWT/SSH/PKI roles, k8s workload onboarding); each input folder has its own `README.md` describing its YAML schema
  - `terraform/aap-platform-user-uhit-dev/` - workspace `aap-platform-user-uhit-dev`: the `uhit-dev` AAP organization (projects, inventories, credentials, teams, job templates); migrated from `terraform-aap-platform-user-iim` with IIM-specific objects removed

## Setup

### 0. Set up bootstrap secret

### 1. Install ArgoCD Operator

Apply the bootstrap manifests to install the Red Hat ArgoCD operator:

```bash
oc apply -f .bootstrap/argocd-namespace.yaml
oc apply -f .bootstrap/argocd-operatorgroup.yaml
oc apply -f .bootstrap/argocd-subscription.yaml
# Wait for operator to be ready
oc apply -f .bootstrap/argocd-instance.yaml
```

### 2. Deploy the App-of-Apps

```bash
oc apply -f argo-apps/app-of-apps.yaml
```

## Testing & Rendering Templates

### Render Auth Chart

To test the auth Helm chart locally:

```bash
helm template auth ./auth
```

With custom values:

```bash
helm template auth ./auth --set github.oauthOpenShiftId=<your-oauth-id>
```

### Render RBAC Chart

To test the RBAC Helm chart locally:

```bash
helm template rbac ./rbac
```

### Render App-of-Apps Chart

To render all child applications managed by the app-of-apps:

```bash
helm template app-of-apps ./argo-apps/app-of-apps
```

This will output all the Application resources that will be created.

To test with custom values:

```bash
helm template app-of-apps ./argo-apps/app-of-apps -f ./argo-apps/app-of-apps/values.yaml
```

### Render All YAML for Deployment

To see everything that will be deployed:

```bash
# All bootstrap manifests
cat .bootstrap/*.yaml

# App-of-apps and all child applications
helm template app-of-apps ./argo-apps/app-of-apps
```