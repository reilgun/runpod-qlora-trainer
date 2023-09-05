#!/bin/bash

# Verify that all required variables are set
if [ -z "$LORA_SCRIPT" ]; then
  echo "Error: Missing one or more required environment variables (LORA_SCRIPT)."
  runpodctl stop pod $RUNPOD_POD_ID
  exit 1
fi

# Preliminary check for S3 access
S3_VARS_SET=false

if [ -n "$AWS_ACCESS_KEY_ID" ] || [ -n "$AWS_SECRET_ACCESS_KEY" ] || [ -n "$S3_BUCKET" ] || [ -n "$S3_ENDPOINT_URL" ]; then
  S3_VARS_SET=true
fi

if [ "$S3_VARS_SET" = true ]; then
  echo "Checking S3 environment variables..."
  
  # Verify that all required variables are set
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$S3_BUCKET" ]; then
    echo "Error: Missing one or more required S3 environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET)."
    runpodctl stop pod $RUNPOD_POD_ID
    exit 1
  fi
  
  echo "Checking S3 access..."
  # Check if a custom S3 endpoint is provided
  if [ -n "$S3_ENDPOINT_URL" ]; then
    echo "Connecting to endpoint $S3_ENDPOINT_URL"

    CHECK_S3_CMD="aws s3 ls s3://$S3_BUCKET/ --debug --endpoint-url $S3_ENDPOINT_URL"
  else
    CHECK_S3_CMD="aws s3 ls s3://$S3_BUCKET/"
  fi

  if ! $CHECK_S3_CMD; then
    echo "Error: Unable to access S3 bucket with the provided credentials or bucket is not writable."
    runpodctl stop pod $RUNPOD_POD_ID
    exit 1
  fi
fi

# Download dataset
if [ -n "$DATASET" ]; then
  if [[ "$DATASET" == s3://* ]] && [ "$S3_VARS_SET" = true ]; then
    # If $DATASET is an S3 URL, and any S3 env variables are set, use aws cli
    if [ -n "$S3_ENDPOINT_URL" ]; then
      aws s3 cp $DATASET /workspace/dataset.jsonl --endpoint-url $S3_ENDPOINT_URL
    else
      aws s3 cp $DATASET /workspace/dataset.jsonl
    fi
  else
    # Otherwise, use curl
    curl -o /workspace/dataset.jsonl $DATASET
  fi
fi

curl -o /workspace/dataset.jsonl $DATASET

# Download the script using the environment variable LORA_SCRIPT
curl -o scripts/run_lora.sh $LORA_SCRIPT

# Make the downloaded script executable
chmod +x scripts/run_lora.sh

# Execute the original start.sh script from the base image in the background
/start.sh &

# Save the PID of the background process
START_SH_PID=$!

mkdir -p /workspace/output
# Execute the downloaded script in the foreground
bash scripts/run_lora.sh >> /workspace/output/train.log 2>&1

# Zip the contents of /workspace/output and upload to S3 if AWS credentials are present
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ -n "$S3_BUCKET" ]; then
  # Generate a filename containing the current date and time with dashes
  TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
  ZIP_FILENAME="/workspace/output_${TIMESTAMP}.zip"

  # Zip the contents
  zip -r $ZIP_FILENAME /workspace/output

  # Check if a custom S3 endpoint is provided
  if [ -n "$S3_ENDPOINT_URL" ]; then
    aws s3 cp $ZIP_FILENAME s3://$S3_BUCKET/ --endpoint-url $S3_ENDPOINT_URL
  else
    aws s3 cp $ZIP_FILENAME s3://$S3_BUCKET/
  fi
fi

# Kill the background start.sh process when your_script.sh finishes
kill $START_SH_PID

# Execute additional commands if any
if [ "$#" -gt 0 ]; then
    "$@"
fi

# Stop the container to save money
runpodctl stop pod $RUNPOD_POD_ID