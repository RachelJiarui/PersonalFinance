#!/bin/bash

# Get Backend URL Script
# Retrieves the Cloud Run service URL for the BudgetInsight backend

set -e

echo "🔍 Getting Cloud Run backend URL..."

# Get the service URL
SERVICE_URL=$(gcloud run services describe budgetinsight-backend \
    --region=us-central1 \
    --format='value(status.url)' 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
    echo "❌ Error: Could not find Cloud Run service 'budgetinsight-backend'"
    echo "   Make sure the service is deployed."
    exit 1
fi

API_URL="${SERVICE_URL}/api"

echo ""
echo "✅ Backend URL found:"
echo "   Service URL: $SERVICE_URL"
echo "   API URL:     $API_URL"
echo ""
echo "📱 To configure iOS app:"
echo "   1. In Xcode, go to Product → Scheme → Edit Scheme..."
echo "   2. Select 'Run' → 'Arguments' tab"
echo "   3. Add Environment Variable:"
echo "      Name:  BACKEND_URL"
echo "      Value: $API_URL"
echo ""
echo "🧪 Testing backend health..."

# Test the health endpoint
HEALTH_RESPONSE=$(curl -s "$SERVICE_URL/health" || echo "error")

if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
    echo "✅ Backend is healthy and responding!"
else
    echo "⚠️  Backend health check failed"
    echo "   Response: $HEALTH_RESPONSE"
fi

echo ""
echo "📋 Save this URL:"
echo "   $API_URL"
