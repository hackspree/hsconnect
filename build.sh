#!/bin/bash

# Function to check if the user is in the docker group
check_docker_group() {
    if groups | grep -q '\bdocker\b'; then
        echo "User is already in the 'docker' group."
    else
        echo "User is not in the 'docker' group. Adding user to the 'docker' group..."
        sudo usermod -aG docker $USER
        echo "User added to the 'docker' group. Please log out and log back in for the changes to take effect."
        echo "After logging back in, re-run this script to continue."
        exit 1
    fi
}

# Check if the user is in the docker group
check_docker_group

# Build the Docker image
echo "Building Docker image 'hs-connect'..."
docker build -t hs-connect .

# Print success message
echo "Docker image 'hs-connect' built successfully!"
