#!/bin/bash
# Setup Cloud Scheduler for Gmail Watch Auto-Renewal
# This script creates a Cloud Scheduler job that runs daily to renew Gmail watches

set -e

echo "🔧 Setting up Gmail Watch Auto-Renewal with Cloud Scheduler"
echo "============================================================"

# Get project ID
PROJECT_ID=$(gcloud config get-value project)
echo "📋 Project ID: $PROJECT_ID"

# Get Cloud Run URL
echo "🔍 Getting Cloud Run URL..."
CLOUD_RUN_URL=$(gcloud run services describe budgetinsight-backend --region=us-central1 --format='value(status.url)')
echo "✅ Cloud Run URL: $CLOUD_RUN_URL"

# Enable Cloud Scheduler API
echo "🔌 Enabling Cloud Scheduler API..."
gcloud services enable cloudscheduler.googleapis.com

# Create service account for Cloud Scheduler (if not exists)
echo "👤 Creating service account for Cloud Scheduler..."
SERVICE_ACCOUNT_NAME="cloud-scheduler-invoker"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &>/dev/null; then
    echo "   Service account already exists"
else
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="Cloud Scheduler Invoker for Gmail Watch Renewal"
    echo "   ✅ Service account created"
fi

# Grant permission to invoke Cloud Run
echo "🔐 Granting Cloud Run invoker permission..."
gcloud run services add-iam-policy-binding budgetinsight-backend \
    --region=us-central1 \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/run.invoker"

# Create Cloud Scheduler job (runs daily at 3 AM UTC)
echo "⏰ Creating Cloud Scheduler job..."
JOB_NAME="gmail-watch-renewal"
SCHEDULE="0 3 * * *"  # Daily at 3 AM UTC
TIMEZONE="America/New_York"  # Adjust to your timezone

# Delete existing job if it exists
if gcloud scheduler jobs describe $JOB_NAME --location=us-central1 &>/dev/null; then
    echo "   Deleting existing job..."
    gcloud scheduler jobs delete $JOB_NAME --location=us-central1 --quiet
fi

# Create new job
gcloud scheduler jobs create http $JOB_NAME \
    --location=us-central1 \
    --schedule="$SCHEDULE" \
    --uri="${CLOUD_RUN_URL}/tasks/renew-watches" \
    --http-method=POST \
    --oidc-service-account-email="${SERVICE_ACCOUNT_EMAIL}" \
    --oidc-token-audience="${CLOUD_RUN_URL}" \
    --time-zone="$TIMEZONE" \
    --attempt-deadline=120s \
    --description="Auto-renewal of Gmail push notification watches"

echo ""
echo "✅ Cloud Scheduler job created successfully!"
echo ""
echo "📊 Job Details:"
echo "   Name: $JOB_NAME"
echo "   Schedule: Daily at 3 AM $TIMEZONE"
echo "   Endpoint: ${CLOUD_RUN_URL}/tasks/renew-watches"
echo ""
echo "🧪 Test the job manually:"
echo "   gcloud scheduler jobs run $JOB_NAME --location=us-central1"
echo ""
echo "📝 View job logs:"
echo "   gcloud scheduler jobs describe $JOB_NAME --location=us-central1"
echo ""
echo "🔄 The job will automatically:"
echo "   • Run daily at 3 AM"
echo "   • Check all Gmail watches"
echo "   • Renew any expiring in < 24 hours"
echo "   • Log results to Cloud Run"
echo ""
echo "✨ Auto-renewal is now active! You never need to manually renew again."
