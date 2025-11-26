#!/bin/bash
# Cross-platform script to wait for Shuffle deployment to be ready.
# Works on Linux and macOS (with bash available).

set -e

if [ "$#" -ne 3 ]; then
    echo "ERROR: Invalid arguments" >&2
    echo "Usage: wait-for-shuffle.sh <frontend_url> <vm_name> <vm_zone>"
    exit 1
fi

FRONTEND_URL="$1"
VM_NAME="$2"
VM_ZONE="$3"

echo "Waiting for Shuffle deployment to complete on primary manager..."
echo "This may take 20-30 minutes for initial deployment..."

# Wait for VM to be ready and SSH accessible
sleep 60

MAX_ATTEMPTS=50
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo ""
    
    URL=${FRONTEND_URL}/api/v1/checkusers
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || true)
    if [ "$RESPONSE" -eq 200 ]; then
        echo "✅ Shuffle is now accessible at: $FRONTEND_URL"
        exit 0
    fi
    
    # Show progress every 5 attempts
    if [ $((ATTEMPT % 5)) -eq 0 ]; then
        echo "Still waiting... ($ATTEMPT minutes elapsed)"
    fi
    
    sleep 60
done

echo ""
echo "⚠️  Timeout waiting for Shuffle to become accessible" >&2
echo "The deployment may still be in progress. Check the VM startup logs:" >&2
echo "  gcloud compute ssh $VM_NAME --zone=$VM_ZONE" >&2
exit 1
