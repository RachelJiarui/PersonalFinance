#!/bin/bash

echo "🔧 Setting up Python virtual environment for backend"
echo ""

# Create venv if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate and install dependencies
echo "Installing dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✅ Virtual environment ready!"
echo ""
echo "To activate the venv, run:"
echo "  source venv/bin/activate"
echo ""
echo "To run the test script:"
echo "  source venv/bin/activate"
echo "  python3 test_gmail_webhook.py --email your.email@gmail.com"
