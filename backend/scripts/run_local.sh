#!/bin/bash

# Run the Flask backend locally
cd "$(dirname "$0")"

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Set environment variables
export FLASK_APP=app.py
export FLASK_ENV=development
export PORT=5001

# Run the app
echo "Starting Flask backend on http://127.0.0.1:5001"
python app.py
