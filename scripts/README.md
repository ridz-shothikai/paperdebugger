# PaperDebugger Deployment Scripts

This directory contains scripts to help deploy PaperDebugger to various cloud platforms.

## Available Scripts

### deploy-cloud-run.sh

Interactive deployment script for Google Cloud Run.

**Usage:**
```bash
./scripts/deploy-cloud-run.sh
```

**What it does:**
- Checks for gcloud CLI installation
- Prompts for project ID and region selection
- Enables required Google Cloud APIs
- Configures MongoDB connection
- Sets up OpenAI API key
- Generates secure JWT signing key
- Deploys PaperDebugger to Cloud Run
- Provides next steps and service URL

**Prerequisites:**
- Google Cloud SDK (gcloud) installed
- Google Cloud account with billing enabled
- MongoDB instance (Atlas or self-hosted)
- OpenAI API key

**Example:**
```bash
cd /path/to/paperdebugger
chmod +x scripts/deploy-cloud-run.sh
./scripts/deploy-cloud-run.sh
```

## Manual Deployment

If you prefer to deploy manually or the script doesn't work for your setup, see the comprehensive guides:

- **Google Cloud Run**: [docs/CLOUD_RUN_DEPLOYMENT.md](../docs/CLOUD_RUN_DEPLOYMENT.md)
- **Quick Reference**: [docs/CLOUD_RUN_COMMANDS.md](../docs/CLOUD_RUN_COMMANDS.md)

## Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/deploy-cloud-run.sh
```

### gcloud Not Found

Install the Google Cloud SDK:
- Visit: https://cloud.google.com/sdk/docs/install

### Authentication Issues

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

## Contributing

To add new deployment scripts:

1. Create the script in this directory
2. Make it executable: `chmod +x scripts/your-script.sh`
3. Update this README with usage instructions
4. Test the script thoroughly before committing

## Support

For issues or questions:
- Check the [full deployment guide](../docs/CLOUD_RUN_DEPLOYMENT.md)
- Join our [Discord](https://discord.gg/WwTMzzt9xD)
- Open an issue on [GitHub](https://github.com/PaperDebugger/paperdebugger/issues)
