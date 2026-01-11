# Deploying Nightscout to Homelab Cluster

This guide walks you through deploying Nightscout on your home Kubernetes cluster using Flux.

## Overview

The deployment consists of:

- **Helm Chart**: Published at <https://gluk0.github.io/helm-nightscout>
- **Flux Resources**: Located in `apps/nightscout/`
- **MongoDB**: Requires external or in-cluster MongoDB (not included)

## Prerequisites

### 1. Publish the Helm Chart (First Time Only)

The Helm chart needs to be published to GitHub Pages. This happens automatically via GitHub Actions when you push changes to Chart.yaml.

To trigger the first release:

```bash
cd /home/rich/Repositories/Personal/helm-nightscout

# Verify Chart.yaml version
cat Chart.yaml | grep version

# If needed, bump version and push
# git add Chart.yaml
# git commit -m "chore: trigger initial release"
# git push origin main

# The GitHub Action will publish the chart to gh-pages branch
```

Enable GitHub Pages in the helm-nightscout repository:

- Go to Settings → Pages
- Set Source to: "Deploy from a branch"
- Select Branch: "gh-pages" / (root)

Verify the chart is published (after action completes):

```bash
curl https://gluk0.github.io/helm-nightscout/index.yaml
```

### 2. Set Up MongoDB

You need a MongoDB instance for Nightscout. Choose one option:

**Option A: MongoDB Atlas (Recommended for simplicity)**

1. Create a free cluster at <https://www.mongodb.com/cloud/atlas>
2. Create a database named "nightscout"
3. Get the connection string

**Option B: Deploy MongoDB in-cluster**

```bash
# Add MongoDB Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Create namespace
kubectl create namespace nightscout

# Install MongoDB
helm install mongodb bitnami/mongodb \
  --namespace nightscout \
  --set auth.rootPassword=your-root-password \
  --set auth.username=nightscout \
  --set auth.password=your-password \
  --set auth.database=nightscout \
  --set persistence.size=8Gi
```

### 3. Create Kubernetes Secret

Create the secret with your MongoDB connection string and API secret:

```bash
# For MongoDB Atlas
kubectl create secret generic nightscout-config -n nightscout \
  --from-literal=mongodb-uri='mongodb+srv://username:password@cluster.mongodb.net/nightscout?retryWrites=true&w=majority' \
  --from-literal=api-secret='your-secret-key-minimum-12-characters'

# For in-cluster MongoDB
kubectl create secret generic nightscout-config -n nightscout \
  --from-literal=mongodb-uri='mongodb://nightscout:your-password@mongodb.nightscout.svc.cluster.local:27017/nightscout' \
  --from-literal=api-secret='your-secret-key-minimum-12-characters'
```

## Deployment Steps

### 1. Review Configuration

Edit `apps/nightscout/helmrelease.yaml` to customize:

```yaml
# Key settings to review:
- ingress.hosts[0].host: "nightscout.home.local"  # Change to your domain
- nightscout.baseUrl: "https://nightscout.home.local"  # Match your domain
- nightscout.enable: [...]  # Enable/disable plugins
- resources.limits/requests  # Adjust based on your cluster capacity
```

### 2. Commit and Push

```bash
cd /home/rich/Repositories/Personal/homelab-cluster

git add apps/nightscout/
git commit -m "feat: add Nightscout deployment"
git push origin main
```

### 3. Trigger Flux Reconciliation

Flux will automatically pick up changes, or manually trigger:

```bash
# Reconcile the git source
flux reconcile source git flux-system

# Reconcile the apps kustomization
flux reconcile kustomization apps

# Watch the deployment
kubectl get helmrelease -n nightscout -w
```

### 4. Verify Deployment

```bash
# Check HelmRelease status
kubectl get helmrelease nightscout -n nightscout

# Check pods
kubectl get pods -n nightscout

# Check logs
kubectl logs -n nightscout -l app.kubernetes.io/name=nightscout

# Check ingress
kubectl get ingress -n nightscout
```

## Accessing Nightscout

Once deployed, access Nightscout at the configured hostname (default: <https://nightscout.home.local>)

### Local DNS Setup

If using `.home.local` domain, add to your `/etc/hosts` or configure your local DNS:

```bash
# Get the ingress IP
kubectl get svc -n istio-system

# Add to /etc/hosts (replace with your ingress IP)
192.168.1.100  nightscout.home.local
```

## Troubleshooting

### HelmRelease Not Ready

```bash
# Check HelmRelease status
kubectl describe helmrelease nightscout -n nightscout

# Check if HelmRepository is ready
kubectl get helmrepository -n flux-system nightscout
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n nightscout -l app.kubernetes.io/name=nightscout

# Common issues:
# - Secret not created
# - MongoDB connection failed
# - Resource constraints
```

### MongoDB Connection Issues

```bash
# Test MongoDB connectivity from a pod
kubectl run -it --rm mongodb-test --image=mongo:latest --restart=Never -n nightscout \
  -- mongosh "your-mongodb-connection-string"
```

## Updating Nightscout

### Update Application Version

Edit `apps/nightscout/helmrelease.yaml`:

```yaml
values:
  image:
    tag: "15.0.4"  # Update to new version
```

Commit and push - Flux will handle the update.

### Update Chart Version

Edit `apps/nightscout/helmrelease.yaml`:

```yaml
spec:
  chart:
    spec:
      version: '1.1.x'  # Update chart version
```

## Customization Examples

### Enable Additional Plugins

Edit `helmrelease.yaml`:

```yaml
nightscout:
  enable:
    - careportal
    - boluscalc
    - pushover      # Add Pushover notifications
    - googlehome    # Add Google Home integration
    - alexa         # Add Alexa integration
```

### Configure Alarms

```yaml
nightscout:
  alarms:
    types: "simple predict"
    urgentHigh: 250
    high: 180
    low: 70
    urgentLow: 55
```

### Add Persistence

Currently, Nightscout stores all data in MongoDB. For local file persistence (plugins, etc.), you can enable a PVC by editing the chart values.

## Next Steps

- Configure your CGM data source (Dexcom, Nightscout uploader, etc.)
- Set up alerts and notifications
- Install Nightscout mobile apps
- Configure additional integrations (Pushover, IFTTT, etc.)

## References

- [Nightscout Documentation](https://nightscout.github.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Helm Chart Repository](https://github.com/gluk0/helm-nightscout)
