#!/bin/bash

set -e  # Exit on error

echo "🚀 Deploying BudgetInsight Backend to Cloud Run"
echo "=================================================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Install it from:"
    echo "   https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ No project set. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "📦 Project: $PROJECT_ID"
echo ""

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found in current directory"
    exit 1
fi

# Load environment variables from .env if it exists
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check required credentials
if [ ! -f "credentials.json" ]; then
    echo "⚠️  Warning: credentials.json not found"
    echo "   Service account credentials will need to be configured"
fi

# Build container with Cloud Build
echo "🔨 Building container with Cloud Build..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/budgetinsight-backend

# Prepare environment variables for Cloud Run
# Note: PORT is automatically set by Cloud Run, don't include it
ENV_VARS="GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
ENV_VARS="$ENV_VARS,PUBSUB_TOPIC=${PUBSUB_TOPIC:-gmail-notifications}"
ENV_VARS="$ENV_VARS,FLASK_ENV=${FLASK_ENV:-production}"

if [ ! -z "$SECRET_KEY" ]; then
    ENV_VARS="$ENV_VARS,SECRET_KEY=$SECRET_KEY"
fi

# Deploy to Cloud Run
echo ""
echo "🚢 Deploying to Cloud Run..."
gcloud run deploy budgetinsight-backend \
  --image gcr.io/$PROJECT_ID/budgetinsight-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --max-instances 10 \
  --min-instances 0 \
  --set-env-vars "$ENV_VARS" \
  --service-account budgetinsight-backend@$PROJECT_ID.iam.gserviceaccount.com

# Get service URL
echo ""
echo "📡 Getting service URL..."
SERVICE_URL=$(gcloud run services describe budgetinsight-backend \
  --region us-central1 \
  --format 'value(status.url)')

echo ""
echo "✅ Deployment complete!"
echo "🌐 Service URL: $SERVICE_URL"
echo ""
