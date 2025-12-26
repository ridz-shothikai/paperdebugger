#!/bin/bash

# PaperDebugger - Google Cloud Run Deployment Script
# This script helps you deploy PaperDebugger to Google Cloud Run

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check if gcloud is installed
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first:"
        echo "  Visit: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    print_success "gcloud CLI is installed"
}

# Check if openssl is installed
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        print_error "openssl is not installed. Please install it first:"
        echo "  On Ubuntu/Debian: sudo apt-get install openssl"
        echo "  On macOS: brew install openssl"
        exit 1
    fi
    print_success "openssl is installed"
}

# Print welcome message
print_header "PaperDebugger - Google Cloud Run Deployment"
echo "This script will help you deploy PaperDebugger to Google Cloud Run."
echo ""

# Check prerequisites
print_info "Checking prerequisites..."
check_gcloud
check_openssl

# Get project ID
print_info "Checking Google Cloud project..."
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    print_warning "No project is currently set."
    echo ""
    read -p "Enter your Google Cloud Project ID (or press Enter to create a new one): " PROJECT_ID
    
    if [ -z "$PROJECT_ID" ]; then
        read -p "Enter a name for your new project: " PROJECT_NAME
        PROJECT_ID=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        print_info "Creating project: $PROJECT_ID"
        gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME" || {
            print_error "Failed to create project. It may already exist."
            read -p "Enter an existing project ID: " PROJECT_ID
        }
    fi
    
    gcloud config set project "$PROJECT_ID"
fi

print_success "Using project: $PROJECT_ID"

# Get region
print_info "Selecting deployment region..."
REGION=$(gcloud config get-value run/region 2>/dev/null)

if [ -z "$REGION" ]; then
    echo ""
    echo "Available regions (recommended for low latency):"
    echo "  1) us-central1 (Iowa)"
    echo "  2) us-east1 (South Carolina)"
    echo "  3) us-west1 (Oregon)"
    echo "  4) europe-west1 (Belgium)"
    echo "  5) asia-east1 (Taiwan)"
    echo "  6) Custom region"
    echo ""
    read -p "Select region [1-6] (default: 1): " region_choice
    
    case $region_choice in
        2) REGION="us-east1" ;;
        3) REGION="us-west1" ;;
        4) REGION="europe-west1" ;;
        5) REGION="asia-east1" ;;
        6) read -p "Enter custom region: " REGION ;;
        *) REGION="us-central1" ;;
    esac
    
    gcloud config set run/region "$REGION"
fi

print_success "Using region: $REGION"

# Enable required APIs
print_header "Enabling Required APIs"
print_info "This may take a few minutes..."

if ! gcloud services enable cloudbuild.googleapis.com --project="$PROJECT_ID"; then
    print_error "Failed to enable Cloud Build API. Please check your billing and permissions."
    exit 1
fi

if ! gcloud services enable run.googleapis.com --project="$PROJECT_ID"; then
    print_error "Failed to enable Cloud Run API. Please check your billing and permissions."
    exit 1
fi

if ! gcloud services enable artifactregistry.googleapis.com --project="$PROJECT_ID"; then
    print_error "Failed to enable Artifact Registry API. Please check your billing and permissions."
    exit 1
fi

print_success "APIs enabled successfully"

# Get MongoDB URI
print_header "MongoDB Configuration"
echo "You need a MongoDB instance for PaperDebugger to store data."
echo ""
echo "Options:"
echo "  1) I have a MongoDB Atlas connection string"
echo "  2) I have a self-hosted MongoDB instance"
echo "  3) I need help setting up MongoDB (opens guide)"
echo ""
read -p "Select option [1-3]: " mongo_choice

case $mongo_choice in
    1|2)
        read -p "Enter your MongoDB connection URI: " MONGO_URI
        while [ -z "$MONGO_URI" ]; do
            print_warning "MongoDB URI is required!"
            read -p "Enter your MongoDB connection URI: " MONGO_URI
        done
        ;;
    3)
        print_info "Opening MongoDB setup guide..."
        echo ""
        echo "Please visit the MongoDB Atlas guide in our documentation:"
        echo "  docs/CLOUD_RUN_DEPLOYMENT.md#option-1-mongodb-atlas-recommended"
        echo ""
        read -p "Press Enter when you have your MongoDB URI ready..."
        read -p "Enter your MongoDB connection URI: " MONGO_URI
        ;;
esac

print_success "MongoDB URI configured"

# Get OpenAI API Key
print_header "OpenAI Configuration"
echo "PaperDebugger requires an OpenAI API key for AI functionality."
echo ""
read -p "Enter your OpenAI API key: " OPENAI_KEY

while [ -z "$OPENAI_KEY" ]; do
    print_warning "OpenAI API key is required!"
    echo "Get your key from: https://platform.openai.com/api-keys"
    read -p "Enter your OpenAI API key: " OPENAI_KEY
done

print_success "OpenAI API key configured"

# Generate JWT signing key
print_info "Generating secure JWT signing key..."
JWT_KEY=$(openssl rand -base64 32)
print_success "JWT signing key generated"

# Service name
SERVICE_NAME="paperdebugger"

# Deployment confirmation
print_header "Deployment Summary"
echo "Project ID:     $PROJECT_ID"
echo "Region:         $REGION"
echo "Service Name:   $SERVICE_NAME"
echo "MongoDB:        ${MONGO_URI:0:30}..."
echo "OpenAI Key:     ${OPENAI_KEY:0:10}..."
echo ""
read -p "Proceed with deployment? (y/n): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Deploy to Cloud Run
print_header "Deploying to Cloud Run"
print_info "Building and deploying... This may take 5-10 minutes."
echo ""

gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars "OPENAI_API_KEY=${OPENAI_KEY}" \
    --set-env-vars "PD_MONGO_URI=${MONGO_URI}" \
    --set-env-vars "JWT_SIGNING_KEY=${JWT_KEY}" \
    --memory 1Gi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --min-instances 0 \
    --project "$PROJECT_ID"

# Get service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format='value(status.url)' --project "$PROJECT_ID")

# Success message
print_header "Deployment Successful! 🎉"
echo ""
print_success "Your PaperDebugger backend is now running!"
echo ""
echo "Service URL: ${GREEN}${SERVICE_URL}${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Test your deployment:"
echo "   curl ${SERVICE_URL}"
echo ""
echo "2. Configure the Chrome Extension:"
echo "   a. Install the PaperDebugger Chrome extension"
echo "   b. Open extension settings"
echo "   c. Click the version number 5 times to enable 'Developer Tools'"
echo "   d. Enter this URL in 'Backend Endpoint': ${SERVICE_URL}"
echo "   e. Save and refresh your Overleaf page"
echo ""
echo "3. View logs:"
echo "   gcloud run services logs read ${SERVICE_NAME} --region ${REGION}"
echo ""
echo "4. Update deployment:"
echo "   Run this script again or use:"
echo "   gcloud run deploy ${SERVICE_NAME} --source . --region ${REGION}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "For more information, see: docs/CLOUD_RUN_DEPLOYMENT.md"
echo ""
