#!/bin/bash

set -e  # Exit on error

echo "☁️  BudgetInsight Cloud Setup Script"
echo "===================================="
echo ""
echo "This script will set up your Google Cloud environment for BudgetInsight"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI not found${NC}"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo -e "${GREEN}✓ gcloud CLI found${NC}"

# Get or set project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo ""
    echo -e "${YELLOW}No project set. Please enter your project ID:${NC}"
    read -p "Project ID: " PROJECT_ID
    gcloud config set project $PROJECT_ID
fi

echo ""
echo -e "${GREEN}📦 Project: $PROJECT_ID${NC}"
echo ""

# Enable required APIs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Enabling Google Cloud APIs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

APIS=(
    "gmail.googleapis.com"
    "pubsub.googleapis.com"
    "run.googleapis.com"
    "firestore.googleapis.com"
    "cloudbuild.googleapis.com"
    "cloudscheduler.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo -n "Enabling $api... "
    gcloud services enable $api --quiet
    echo -e "${GREEN}✓${NC}"
done

echo ""
echo -e "${GREEN}✅ All APIs enabled${NC}"

# Create Firestore database
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Firestore Database"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Firestore database exists
if gcloud firestore databases describe --database='(default)' &> /dev/null; then
    echo -e "${GREEN}✓ Firestore database already exists${NC}"
else
    echo -e "${YELLOW}Firestore database not found.${NC}"
    echo "Please create it manually:"
    echo "1. Go to https://console.cloud.google.com/firestore"
    echo "2. Click 'Create Database'"
    echo "3. Choose 'Native mode'"
    echo "4. Select location: us-central1"
    echo "5. Click 'Create'"
    echo ""
    read -p "Press Enter once you've created the database..."
fi

# Create service account
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Service Account"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SERVICE_ACCOUNT="budgetinsight-backend"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"

# Check if service account exists
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &> /dev/null; then
    echo -e "${GREEN}✓ Service account already exists: $SERVICE_ACCOUNT_EMAIL${NC}"
else
    echo "Creating service account: $SERVICE_ACCOUNT"
    gcloud iam service-accounts create $SERVICE_ACCOUNT \
        --display-name="BudgetInsight Backend Service Account"
    echo -e "${GREEN}✓ Service account created${NC}"
fi

# Grant necessary roles
echo ""
echo "Granting IAM roles to service account..."

ROLES=(
    "roles/datastore.user"
    "roles/pubsub.editor"
    "roles/logging.logWriter"
)

for role in "${ROLES[@]}"; do
    echo -n "Granting $role... "
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role" \
        --quiet &> /dev/null
    echo -e "${GREEN}✓${NC}"
done

# Download service account key
echo ""
if [ -f "credentials.json" ]; then
    echo -e "${YELLOW}⚠️  credentials.json already exists${NC}"
    read -p "Do you want to create a new key? (y/N): " CREATE_NEW_KEY
    if [[ $CREATE_NEW_KEY =~ ^[Yy]$ ]]; then
        mv credentials.json credentials.json.backup
        echo "Backed up old credentials to credentials.json.backup"
        gcloud iam service-accounts keys create credentials.json \
            --iam-account=$SERVICE_ACCOUNT_EMAIL
        echo -e "${GREEN}✓ New credentials downloaded to credentials.json${NC}"
    fi
else
    echo "Downloading service account key..."
    gcloud iam service-accounts keys create credentials.json \
        --iam-account=$SERVICE_ACCOUNT_EMAIL
    echo -e "${GREEN}✓ Credentials downloaded to credentials.json${NC}"
fi

# Create Pub/Sub topic
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Pub/Sub Topic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOPIC_NAME="gmail-notifications"

if gcloud pubsub topics describe $TOPIC_NAME &> /dev/null; then
    echo -e "${GREEN}✓ Pub/Sub topic already exists: $TOPIC_NAME${NC}"
else
    echo "Creating Pub/Sub topic: $TOPIC_NAME"
    gcloud pubsub topics create $TOPIC_NAME
    echo -e "${GREEN}✓ Topic created${NC}"
fi

# Grant Gmail permission to publish
echo ""
echo "Granting Gmail API permission to publish to Pub/Sub..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
    --role=roles/pubsub.publisher \
    --quiet &> /dev/null
echo -e "${GREEN}✓ Gmail API permissions granted${NC}"

# Create .env file if it doesn't exist
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Environment Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file already exists${NC}"
    read -p "Do you want to update it? (y/N): " UPDATE_ENV
    if [[ ! $UPDATE_ENV =~ ^[Yy]$ ]]; then
        echo "Skipping .env update"
    else
        mv .env .env.backup
        echo "Backed up old .env to .env.backup"
        cp .env.example .env
        sed -i.bak "s/GOOGLE_CLOUD_PROJECT=.*/GOOGLE_CLOUD_PROJECT=$PROJECT_ID/" .env
        sed -i.bak "s/SECRET_KEY=.*/SECRET_KEY=$(openssl rand -hex 32)/" .env
        rm .env.bak
        echo -e "${GREEN}✓ .env file updated${NC}"
        echo -e "${YELLOW}⚠️  Don't forget to add your APNs certificates!${NC}"
    fi
else
    cp .env.example .env
    sed -i.bak "s/GOOGLE_CLOUD_PROJECT=.*/GOOGLE_CLOUD_PROJECT=$PROJECT_ID/" .env
    sed -i.bak "s/SECRET_KEY=.*/SECRET_KEY=$(openssl rand -hex 32)/" .env
    rm .env.bak
    echo -e "${GREEN}✓ .env file created${NC}"
    echo -e "${YELLOW}⚠️  Don't forget to add your APNs certificates!${NC}"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cloud Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}What was set up:${NC}"
echo "  ✓ Google Cloud APIs enabled"
echo "  ✓ Firestore database ready"
echo "  ✓ Service account created with IAM roles"
echo "  ✓ Service account key downloaded (credentials.json)"
echo "  ✓ Pub/Sub topic created (gmail-notifications)"
echo "  ✓ Gmail API permissions granted"
echo "  ✓ Environment variables configured (.env)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Add your APNs certificates to the backend/ directory:"
echo "   - apns_cert.pem"
echo "   - apns_key.pem"
echo ""
echo "2. Deploy the backend to Cloud Run:"
echo "   cd backend"
echo "   ./deploy.sh"
echo ""
echo "3. After deployment, set up Gmail push notifications:"
echo "   python3 setup_gmail_push.py --email your.email@gmail.com"
echo ""
echo "4. Set up auto-renewal for Gmail watch:"
echo "   ./setup_auto_renewal.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
