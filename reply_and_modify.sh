#!/bin/bash

# Check for required arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <admin-user> <admin-password> <job-name>"
    exit 1
fi

# Configuration
ADMIN_USER="$1"
ADMIN_PASSWORD="$2"
JOB_NAME="$3"
JENKINS_URL="http://localhost:8080"
JENKINS_CLI_JAR="/tmp/jenkins-cli.jar"
CUSTOM_STEP="sh 'echo Custom Step Executed'"

# Download Jenkins CLI if not already downloaded
if [ ! -f "$JENKINS_CLI_JAR" ]; then
    echo "[INFO] Downloading Jenkins CLI..."
    wget -q "$JENKINS_URL/jnlpJars/jenkins-cli.jar" -O "$JENKINS_CLI_JAR"
fi

# Get the latest build number
LATEST_BUILD=$(java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$ADMIN_USER:$ADMIN_PASSWORD" list-builds "$JOB_NAME" | head -n 1 | awk '{print $1}')

if [ -z "$LATEST_BUILD" ]; then
    echo "[ERROR] No builds found for job $JOB_NAME."
    exit 1
fi

echo "[INFO] Latest build for $JOB_NAME: #$LATEST_BUILD"

# Get the Pipeline script from the latest build
BUILD_SCRIPT=$(curl -s -u "$ADMIN_USER:$ADMIN_PASSWORD" "$JENKINS_URL/job/$JOB_NAME/$LATEST_BUILD/replay/pipelineSyntax")

if [ -z "$BUILD_SCRIPT" ]; then
    echo "[ERROR] Failed to retrieve pipeline script for build #$LATEST_BUILD."
    exit 1
fi

echo "[INFO] Original Pipeline Script:"
echo "$BUILD_SCRIPT"

# Modify the Pipeline script by adding the custom step
MODIFIED_SCRIPT=$(echo "$BUILD_SCRIPT" | sed "/^pipeline {/a \
        stage('Custom Step') { \
            steps { \
                $CUSTOM_STEP \
            } \
        }")

echo "[INFO] Modified Pipeline Script:"
echo "$MODIFIED_SCRIPT"

# Save the modified script to a temporary file
MODIFIED_SCRIPT_FILE="/tmp/modified_pipeline.groovy"
echo "$MODIFIED_SCRIPT" > "$MODIFIED_SCRIPT_FILE"

# Replay the build with the modified script
RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASSWORD" -X POST -F "script=@$MODIFIED_SCRIPT_FILE" "$JENKINS_URL/job/$JOB_NAME/$LATEST_BUILD/replay/run")

if [[ "$RESPONSE" == *"build"* ]]; then
    echo "[INFO] Build replay initiated successfully with the modified script."
else
    echo "[ERROR] Failed to replay the build. Response: $RESPONSE"
fi

# Clean up temporary files
rm -f "$MODIFIED_SCRIPT_FILE"

echo "[INFO] Script execution completed."
