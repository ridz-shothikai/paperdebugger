# Deploying PaperDebugger to Google Cloud Run

This guide provides step-by-step instructions for deploying the self-hosted version of PaperDebugger to Google Cloud Run.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [MongoDB Setup Options](#mongodb-setup-options)
- [Deployment Steps](#deployment-steps)
- [Environment Variables Configuration](#environment-variables-configuration)
- [Testing Your Deployment](#testing-your-deployment)
- [Custom Domain Setup](#custom-domain-setup-optional)
- [Scaling and Performance](#scaling-and-performance)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)

## Prerequisites

Before you begin, ensure you have:

1. **Google Cloud Account**: Active GCP account with billing enabled
2. **Google Cloud SDK**: Install `gcloud` CLI tool
   ```bash
   # Install gcloud CLI
   # Visit: https://cloud.google.com/sdk/docs/install
   
   # Verify installation
   gcloud --version
   ```

3. **Docker**: For building container images locally (optional)
   ```bash
   docker --version
   ```

4. **OpenAI API Key**: Required for AI functionality
   - Sign up at [OpenAI Platform](https://platform.openai.com/)
   - Generate an API key from your account dashboard

5. **MongoDB Instance**: Choose one of the options in the next section

## Architecture Overview

The deployment consists of two main components:

1. **PaperDebugger Backend** (Cloud Run service)
   - Go-based HTTP/gRPC API server
   - Handles authentication, AI chat, and project management
   - Requires connection to MongoDB

2. **MongoDB Database** (External or Cloud-based)
   - Stores user data, chat history, and project information
   - Can be self-hosted or managed service

## MongoDB Setup Options

### Option 1: MongoDB Atlas (Recommended)

MongoDB Atlas is a fully managed cloud database service with a free tier.

1. **Create MongoDB Atlas Account**
   - Visit [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
   - Sign up for a free account

2. **Create a Cluster**
   - Click "Build a Database"
   - Choose "M0 Sandbox" (Free tier)
   - Select a cloud provider and region (preferably same region as your Cloud Run service)
   - Click "Create"

3. **Configure Network Access**
   - Go to "Network Access" in the left sidebar
   - Click "Add IP Address"
   - Click "Allow Access from Anywhere" (0.0.0.0/0)
   - Confirm (Note: For production, restrict to Cloud Run's IP ranges)

4. **Create Database User**
   - Go to "Database Access" in the left sidebar
   - Click "Add New Database User"
   - Choose "Password" authentication
   - Create username and strong password
   - Set role to "Atlas admin" or "Read and write to any database"
   - Click "Add User"

5. **Get Connection String**
   - Go to "Database" and click "Connect"
   - Choose "Connect your application"
   - Copy the connection string (looks like: `mongodb+srv://username:password@cluster.xxxxx.mongodb.net/`)
   - Replace `<password>` with your actual password
   - Add database name at the end: `mongodb+srv://username:password@cluster.xxxxx.mongodb.net/paperdebugger`

### Option 2: Self-Hosted MongoDB on Google Cloud

If you prefer to host MongoDB yourself on GCP:

1. **Create a Compute Engine VM**
   ```bash
   gcloud compute instances create mongodb-instance \
     --zone=us-central1-a \
     --machine-type=e2-medium \
     --image-family=ubuntu-2204-lts \
     --image-project=ubuntu-os-cloud \
     --boot-disk-size=50GB
   ```

2. **SSH into the VM and Install MongoDB**
   ```bash
   gcloud compute ssh mongodb-instance --zone=us-central1-a
   
   # Install MongoDB
   wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
   echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
   sudo apt-get update
   sudo apt-get install -y mongodb-org
   
   # Start MongoDB
   sudo systemctl start mongod
   sudo systemctl enable mongod
   ```

3. **Configure MongoDB for Remote Access**
   ```bash
   sudo nano /etc/mongod.conf
   # Change bindIp from 127.0.0.1 to 0.0.0.0
   # Save and exit
   
   sudo systemctl restart mongod
   ```

4. **Configure Firewall**
   ```bash
   gcloud compute firewall-rules create mongodb-allow \
     --allow tcp:27017 \
     --source-ranges=0.0.0.0/0 \
     --description="Allow MongoDB access"
   ```

5. **Get MongoDB URI**
   - Your URI will be: `mongodb://<EXTERNAL_IP>:27017`
   - Get external IP: `gcloud compute instances describe mongodb-instance --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)'`

### Option 3: Google Cloud Memorystore for MongoDB (Enterprise)

For production environments, consider using Google Cloud's managed MongoDB service.

## Deployment Steps

### Step 1: Set Up Google Cloud Project

> **Note**: Throughout this guide, we use `paperdebugger-prod` as an example project ID. Replace it with your own unique project ID.

1. **Create or Select a Project**
   ```bash
   # Create a new project (replace 'paperdebugger-prod' with your unique project ID)
   gcloud projects create paperdebugger-prod --name="PaperDebugger Production"
   
   # Or list existing projects
   gcloud projects list
   
   # Set the project
   gcloud config set project paperdebugger-prod
   ```

2. **Enable Required APIs**
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

3. **Set Default Region**
   ```bash
   # Choose a region close to your users
   gcloud config set run/region us-central1
   ```

### Step 2: Prepare the Application

1. **Clone the Repository** (if not already done)
   ```bash
   git clone https://github.com/PaperDebugger/paperdebugger.git
   cd paperdebugger
   ```

2. **Test Build Locally** (optional but recommended)
   ```bash
   docker build -t paperdebugger:test .
   docker run -p 6060:8080 \
     -e OPENAI_API_KEY=your-openai-key \
     -e PD_MONGO_URI=your-mongo-uri \
     -e PORT=8080 \
     paperdebugger:test
   ```

### Step 3: Deploy to Cloud Run

#### Method A: Deploy from Source (Simplest)

This method builds the container in Cloud Build and deploys directly:

```bash
gcloud run deploy paperdebugger \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "OPENAI_API_KEY=your-openai-key-here" \
  --set-env-vars "PD_MONGO_URI=your-mongodb-uri-here" \
  --set-env-vars "JWT_SIGNING_KEY=your-secret-jwt-key" \
  --memory 1Gi \
  --cpu 1 \
  --timeout 300 \
  --max-instances 10 \
  --min-instances 0
```

Replace the following:
- `your-openai-key-here`: Your OpenAI API key
- `your-mongodb-uri-here`: Your MongoDB connection URI
- `your-secret-jwt-key`: A secure random string for JWT signing (generate one: `openssl rand -base64 32`)

#### Method B: Build and Deploy with Artifact Registry

For more control over the build process:

1. **Create Artifact Registry Repository**
   ```bash
   gcloud artifacts repositories create paperdebugger-repo \
     --repository-format=docker \
     --location=us-central1 \
     --description="PaperDebugger Docker repository"
   ```

2. **Build and Push the Image**
   ```bash
   # Configure Docker authentication
   gcloud auth configure-docker us-central1-docker.pkg.dev
   
   # Build the image
   docker build -t us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:latest .
   
   # Push the image
   docker push us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:latest
   ```

3. **Deploy to Cloud Run**
   ```bash
   gcloud run deploy paperdebugger \
     --image us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:latest \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --set-env-vars "OPENAI_API_KEY=your-openai-key-here" \
     --set-env-vars "PD_MONGO_URI=your-mongodb-uri-here" \
     --set-env-vars "JWT_SIGNING_KEY=your-secret-jwt-key" \
     --memory 1Gi \
     --cpu 1 \
     --timeout 300 \
     --max-instances 10 \
     --min-instances 0
   ```

### Step 4: Get Your Service URL

After deployment completes, Cloud Run will provide a URL:

```bash
# Get the service URL
gcloud run services describe paperdebugger --region us-central1 --format='value(status.url)'
```

Your PaperDebugger backend will be available at: `https://paperdebugger-xxxxx-uc.a.run.app`

## Environment Variables Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key for AI functionality | `sk-proj-xxxxx` |
| `PD_MONGO_URI` | MongoDB connection string | `mongodb+srv://user:pass@cluster.mongodb.net/paperdebugger` |
| `JWT_SIGNING_KEY` | Secret key for JWT token signing | `your-secure-random-string` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_BASE_URL` | Custom OpenAI API endpoint | `https://api.openai.com/v1` |
| `INFERENCE_BASE_URL` | Custom inference endpoint | `https://inference.paperdebugger.workers.dev` |
| `INFERENCE_API_KEY` | API key for custom inference endpoint | (none) |
| `XTRAMCP_URI` | XtraMCP server URL (optional) | `http://paperdebugger-xtramcp-server:8080/mcp` |
| `MCP_SERVER_URL` | MCP server URL (optional) | `http://paperdebugger-mcp-server:8000` |

### Using Secret Manager (Recommended for Production)

For better security, store sensitive data in Google Secret Manager:

1. **Create Secrets**
   ```bash
   # Create secret for OpenAI API Key
   echo -n "your-openai-key-here" | gcloud secrets create openai-api-key --data-file=-
   
   # Create secret for MongoDB URI
   echo -n "your-mongodb-uri" | gcloud secrets create mongo-uri --data-file=-
   
   # Create secret for JWT signing key
   openssl rand -base64 32 | gcloud secrets create jwt-signing-key --data-file=-
   ```

2. **Grant Access to Cloud Run**
   ```bash
   # Get the Cloud Run service account
   PROJECT_NUMBER=$(gcloud projects describe paperdebugger-prod --format='value(projectNumber)')
   SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
   
   # Grant access to secrets
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

3. **Deploy with Secrets**
   ```bash
   gcloud run deploy paperdebugger \
     --source . \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --update-secrets="OPENAI_API_KEY=openai-api-key:latest" \
     --update-secrets="PD_MONGO_URI=mongo-uri:latest" \
     --update-secrets="JWT_SIGNING_KEY=jwt-signing-key:latest" \
     --memory 1Gi \
     --cpu 1 \
     --timeout 300 \
     --max-instances 10 \
     --min-instances 0
   ```

## Testing Your Deployment

### 1. Health Check

Test if the service is running:

```bash
SERVICE_URL=$(gcloud run services describe paperdebugger --region us-central1 --format='value(status.url)')
curl -I $SERVICE_URL
```

You should receive a `200 OK` or similar response.

### 2. API Endpoint Test

Test a specific API endpoint:

```bash
# Test the health endpoint (if available)
curl $SERVICE_URL/health

# Or test the base endpoint
curl $SERVICE_URL/
```

### 3. Configure Chrome Extension

1. Install the PaperDebugger Chrome extension
2. Open the extension settings
3. Click the version number 5 times to enable "Developer Tools"
4. Enter your Cloud Run service URL in the "Backend Endpoint" field
5. Save and refresh your Overleaf page

### 4. Test with Overleaf

1. Open any Overleaf project
2. Click the PaperDebugger icon
3. Try sending a chat message
4. Verify the AI responds correctly

## Custom Domain Setup (Optional)

To use a custom domain instead of the default Cloud Run URL:

### Step 1: Domain Mapping

1. **Map the Domain**
   ```bash
   gcloud run domain-mappings create \
     --service paperdebugger \
     --domain api.yourdomain.com \
     --region us-central1
   ```

2. **Get DNS Records**
   ```bash
   gcloud run domain-mappings describe \
     --domain api.yourdomain.com \
     --region us-central1
   ```

### Step 2: Update DNS

Add the provided DNS records to your domain registrar:
- Type: A and AAAA records
- Name: api (or your subdomain)
- Value: The IP addresses provided by Cloud Run

### Step 3: SSL Certificate

Cloud Run automatically provisions SSL certificates for custom domains. Wait 15-30 minutes for certificate issuance.

### Step 4: Verify

```bash
curl https://api.yourdomain.com
```

## Scaling and Performance

### Configure Auto-scaling

```bash
gcloud run services update paperdebugger \
  --region us-central1 \
  --min-instances 0 \
  --max-instances 100 \
  --concurrency 80
```

**Parameters Explained:**
- `min-instances`: Minimum number of container instances (0 = scale to zero)
- `max-instances`: Maximum number of instances
- `concurrency`: Maximum concurrent requests per instance

### Resource Allocation

For better performance:

```bash
gcloud run services update paperdebugger \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300
```

### Cost Optimization Tips

1. **Scale to Zero**: Set `min-instances=0` for low-traffic periods
2. **Right-size Resources**: Start with 1Gi RAM and 1 CPU, adjust based on monitoring
3. **Optimize Cold Starts**: Use `min-instances=1` for production if cold starts are problematic
4. **Monitor Usage**: Use Cloud Monitoring to track requests and optimize

## Troubleshooting

### Issue: Deployment Fails

**Solution**: Check Cloud Build logs
```bash
gcloud builds list --limit=5
gcloud builds log <BUILD_ID>
```

### Issue: Service Doesn't Start

**Solution**: Check Cloud Run logs
```bash
gcloud run services logs read paperdebugger --region us-central1 --limit=50
```

### Issue: MongoDB Connection Errors

**Possible causes:**
1. Incorrect MongoDB URI
2. MongoDB network access not configured (Atlas)
3. Firewall blocking connections (self-hosted)

**Solution**: 
```bash
# Test MongoDB connection from Cloud Shell
docker run -it --rm mongo mongosh "your-mongodb-uri"
```

### Issue: OpenAI API Errors

**Solution**: Verify your OpenAI API key
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer your-api-key"
```

### Issue: 503 Service Unavailable

**Possible causes:**
1. Container startup timeout
2. Health check failures
3. Insufficient resources

**Solution**: Increase timeout and resources
```bash
gcloud run services update paperdebugger \
  --region us-central1 \
  --timeout 600 \
  --memory 2Gi
```

### Issue: Cold Start Latency

**Solution**: Use minimum instances
```bash
gcloud run services update paperdebugger \
  --region us-central1 \
  --min-instances 1
```

### Debugging Tips

1. **Enable Detailed Logging**
   ```bash
   gcloud run services logs tail paperdebugger --region us-central1
   ```

2. **Check Environment Variables**
   ```bash
   gcloud run services describe paperdebugger --region us-central1 --format="yaml(spec.template.spec.containers[0].env)"
   ```

3. **Test Locally**
   ```bash
   docker run -p 8080:8080 \
     -e OPENAI_API_KEY=your-key \
     -e PD_MONGO_URI=your-uri \
     -e JWT_SIGNING_KEY=your-secret \
     -e PORT=8080 \
     us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:latest
   ```

## Cost Estimation

### Cloud Run Pricing (as of 2024)

Cloud Run charges for:
- **CPU**: ~$0.00002400/vCPU-second
- **Memory**: ~$0.00000250/GiB-second
- **Requests**: $0.40 per million requests
- **Free Tier**: 2 million requests, 360,000 GiB-seconds, 180,000 vCPU-seconds per month

### Example Monthly Costs

**Low Traffic (< 10k requests/month)**
- Cloud Run: Free tier covers it
- MongoDB Atlas: Free (M0 tier)
- **Total: $0/month**

**Medium Traffic (100k requests/month)**
- Cloud Run: ~$5-10/month
- MongoDB Atlas: Free or $9/month (M2 tier)
- **Total: ~$5-20/month**

**High Traffic (1M requests/month)**
- Cloud Run: ~$50-100/month
- MongoDB Atlas: $57/month (M10 tier)
- OpenAI API: Variable based on usage
- **Total: ~$107-157/month + OpenAI costs**

### Monitor Costs

```bash
# View billing
gcloud billing projects describe paperdebugger-prod
```

Set up budget alerts in the [GCP Console](https://console.cloud.google.com/billing/budgets).

## Updating Your Deployment

### Deploy New Version

```bash
# From source
gcloud run deploy paperdebugger \
  --source . \
  --region us-central1

# From image
docker build -t us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:v2 .
docker push us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:v2
gcloud run services update paperdebugger \
  --image us-central1-docker.pkg.dev/paperdebugger-prod/paperdebugger-repo/paperdebugger:v2 \
  --region us-central1
```

### Rollback to Previous Version

```bash
# List revisions
gcloud run revisions list --service paperdebugger --region us-central1

# Rollback
gcloud run services update-traffic paperdebugger \
  --to-revisions=paperdebugger-00002-abc=100 \
  --region us-central1
```

## Security Best Practices

1. **Use Secret Manager** for sensitive data
2. **Enable VPC Connector** for private MongoDB access
3. **Implement Rate Limiting** in your application
4. **Use Service Accounts** with minimal permissions
5. **Enable Cloud Armor** for DDoS protection (if needed)
6. **Regular Updates**: Keep dependencies and base images updated

## Additional Resources

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [PaperDebugger Development Guide](./DEVELOPMENT.md)
- [OpenAI API Documentation](https://platform.openai.com/docs)

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Cloud Run logs
3. Join the [PaperDebugger Discord](https://discord.gg/WwTMzzt9xD)
4. Open an issue on [GitHub](https://github.com/PaperDebugger/paperdebugger/issues)

---

**Note**: This guide assumes you're using the default configuration. For advanced configurations (XtraMCP, custom MCP servers), refer to the main [DEVELOPMENT.md](./DEVELOPMENT.md) documentation.
