# Cloud Run Quick Reference

This document provides quick reference commands for managing your PaperDebugger deployment on Google Cloud Run.

## Quick Deploy

The fastest way to deploy:

```bash
./scripts/deploy-cloud-run.sh
```

Or manually:

```bash
gcloud run deploy paperdebugger \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

## Common Commands

### View Service Information

```bash
# Get service URL
gcloud run services describe paperdebugger \
  --region us-central1 \
  --format='value(status.url)'

# Get detailed service info
gcloud run services describe paperdebugger --region us-central1

# List all Cloud Run services
gcloud run services list
```

### Logs and Monitoring

```bash
# View recent logs
gcloud run services logs read paperdebugger --region us-central1

# Stream logs in real-time
gcloud run services logs tail paperdebugger --region us-central1

# View logs from last hour
gcloud run services logs read paperdebugger \
  --region us-central1 \
  --limit=100 \
  --format="table(timestamp,severity,textPayload)"
```

### Update Configuration

```bash
# Update environment variable
gcloud run services update paperdebugger \
  --region us-central1 \
  --set-env-vars "OPENAI_API_KEY=new-key"

# Update multiple environment variables
gcloud run services update paperdebugger \
  --region us-central1 \
  --set-env-vars "OPENAI_API_KEY=new-key,PD_MONGO_URI=new-uri"

# Update memory and CPU
gcloud run services update paperdebugger \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2

# Update scaling settings
gcloud run services update paperdebugger \
  --region us-central1 \
  --min-instances 1 \
  --max-instances 20
```

### Deployment and Rollback

```bash
# Deploy new version from source
gcloud run deploy paperdebugger \
  --source . \
  --region us-central1

# List revisions
gcloud run revisions list \
  --service paperdebugger \
  --region us-central1

# Rollback to specific revision
gcloud run services update-traffic paperdebugger \
  --region us-central1 \
  --to-revisions=paperdebugger-00005-abc=100

# Split traffic between revisions (canary deployment)
gcloud run services update-traffic paperdebugger \
  --region us-central1 \
  --to-revisions=paperdebugger-00006-def=90,paperdebugger-00005-abc=10
```

### Service Management

```bash
# Delete service
gcloud run services delete paperdebugger --region us-central1

# Enable unauthenticated access
gcloud run services add-iam-policy-binding paperdebugger \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

# Remove unauthenticated access
gcloud run services remove-iam-policy-binding paperdebugger \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"
```

### Testing and Debugging

```bash
# Test the service
SERVICE_URL=$(gcloud run services describe paperdebugger \
  --region us-central1 \
  --format='value(status.url)')

curl -I $SERVICE_URL

# Test with authentication (if enabled)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" $SERVICE_URL
```

### Cost Monitoring

```bash
# View service metrics
gcloud run services describe paperdebugger \
  --region us-central1 \
  --format="yaml(status.traffic)"

# Check billing
gcloud billing projects describe $(gcloud config get-value project)
```

## Using Secret Manager

### Create Secrets

```bash
# Create secret for OpenAI API Key
echo -n "your-openai-key" | gcloud secrets create openai-api-key --data-file=-

# Create secret for MongoDB URI
echo -n "your-mongodb-uri" | gcloud secrets create mongo-uri --data-file=-

# Create secret for JWT signing key
openssl rand -base64 32 | gcloud secrets create jwt-signing-key --data-file=-
```

### Grant Access

```bash
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) \
  --format='value(projectNumber)')
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding mongo-uri \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding jwt-signing-key \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"
```

### Deploy with Secrets

```bash
gcloud run deploy paperdebugger \
  --source . \
  --region us-central1 \
  --update-secrets="OPENAI_API_KEY=openai-api-key:latest" \
  --update-secrets="PD_MONGO_URI=mongo-uri:latest" \
  --update-secrets="JWT_SIGNING_KEY=jwt-signing-key:latest"
```

### Update Secrets

```bash
# Update a secret value
echo -n "new-value" | gcloud secrets versions add openai-api-key --data-file=-

# List secret versions
gcloud secrets versions list openai-api-key

# Delete old secret versions
gcloud secrets versions destroy 1 --secret=openai-api-key
```

## Custom Domain Setup

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service paperdebugger \
  --domain api.yourdomain.com \
  --region us-central1

# Get DNS records to configure
gcloud run domain-mappings describe \
  --domain api.yourdomain.com \
  --region us-central1

# List domain mappings
gcloud run domain-mappings list --region us-central1

# Delete domain mapping
gcloud run domain-mappings delete \
  --domain api.yourdomain.com \
  --region us-central1
```

## Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# PaperDebugger Cloud Run aliases
alias pd-deploy='gcloud run deploy paperdebugger --source . --region us-central1'
alias pd-logs='gcloud run services logs tail paperdebugger --region us-central1'
alias pd-url='gcloud run services describe paperdebugger --region us-central1 --format="value(status.url)"'
alias pd-info='gcloud run services describe paperdebugger --region us-central1'
alias pd-revisions='gcloud run revisions list --service paperdebugger --region us-central1'
```

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | OpenAI API key |
| `PD_MONGO_URI` | Yes | MongoDB connection URI |
| `JWT_SIGNING_KEY` | Yes | JWT token signing key |
| `PORT` | No | Port number (set by Cloud Run) |
| `OPENAI_BASE_URL` | No | Custom OpenAI endpoint |
| `INFERENCE_BASE_URL` | No | Custom inference endpoint |
| `INFERENCE_API_KEY` | No | Inference API key |
| `XTRAMCP_URI` | No | XtraMCP server URL |
| `MCP_SERVER_URL` | No | MCP server URL |

## Troubleshooting

### Service won't start

```bash
# Check logs for errors
gcloud run services logs read paperdebugger --region us-central1 --limit=50

# Increase timeout and memory
gcloud run services update paperdebugger \
  --region us-central1 \
  --timeout 600 \
  --memory 2Gi
```

### MongoDB connection issues

```bash
# Test MongoDB connectivity from Cloud Shell
docker run -it --rm mongo mongosh "your-mongodb-uri"

# Update MongoDB URI
gcloud run services update paperdebugger \
  --region us-central1 \
  --set-env-vars "PD_MONGO_URI=new-uri"
```

### High latency

```bash
# Enable minimum instances
gcloud run services update paperdebugger \
  --region us-central1 \
  --min-instances 1

# Increase CPU
gcloud run services update paperdebugger \
  --region us-central1 \
  --cpu 2
```

## Additional Resources

- [Full Deployment Guide](CLOUD_RUN_DEPLOYMENT.md)
- [Development Setup](DEVELOPMENT.md)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
