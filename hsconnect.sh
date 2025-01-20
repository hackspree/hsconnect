#!/bin/bash

# Function to check if a port is in use
is_port_in_use() {
    if sudo lsof -i :$1 &> /dev/null; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to kill the process using a port
kill_process_using_port() {
    local port=$1
    echo "Port $port is in use. Killing the process..."
    sudo lsof -i :$port | awk 'NR==2 {print $2}' | xargs -r sudo kill -9
    echo "Process using port $port has been killed."
}

# Function to create necessary files
create_files() {
    mkdir -p /tmp/hs-connect
    cd /tmp/hs-connect

    # Create Dockerfile
    cat <<EOF > Dockerfile
# Use the official Go image as the base
FROM golang:1.20 AS builder

# Set the working directory
WORKDIR /app

# Copy the Go HTTP server code
COPY server.go .

# Build the Go HTTP server
RUN go build -o hs-connect server.go

# Use a lightweight base image for the final stage
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \\
    apt-get install -y wget curl && \\
    rm -rf /var/lib/apt/lists/*

# Install IPFS
RUN wget https://dist.ipfs.tech/kubo/v0.23.0/kubo_v0.23.0_linux-amd64.tar.gz && \\
    tar -xvzf kubo_v0.23.0_linux-amd64.tar.gz && \\
    cd kubo && \\
    bash install.sh && \\
    cd .. && \\
    rm -rf kubo kubo_v0.23.0_linux-amd64.tar.gz

# Copy the Go HTTP server binary from the builder stage
COPY --from=builder /app/hs-connect /usr/local/bin/hs-connect

# Copy the startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports
EXPOSE 4001 5001 8080 80

# Start the container
ENTRYPOINT ["/start.sh"]
EOF

    # Create server.go
    cat <<EOF > server.go
package main

import (
	"fmt"
	"net/http"
	"os/exec"
)

func main() {
	// Define the /connect endpoint
	http.HandleFunc("/connect", func(w http.ResponseWriter, r *http.Request) {
		// Get the bootstrap address
		bootstrapAddress, err := getBootstrapAddress()
		if err != nil {
			http.Error(w, "Failed to get bootstrap address", http.StatusInternalServerError)
			return
		}

		// Write the response
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprintf(w, \`
<!DOCTYPE html>
<html>
<head>
    <title>IPFS Bootstrap Node Information</title>
</head>
<body>
    <h1>IPFS Bootstrap Node Information</h1>
    <p><strong>Bootstrap Address:</strong> %s</p>
</body>
</html>
\`, bootstrapAddress)
	})

	// Start the HTTP server on port 80
	fmt.Println("Starting HTTP server on :80...")
	if err := http.ListenAndServe(":80", nil); err != nil {
		fmt.Printf("Error starting HTTP server: %v\n", err)
	}
}

// getBootstrapAddress retrieves the bootstrap address using the IPFS CLI
func getBootstrapAddress() (string, error) {
	// Get the public IP address
	publicIP, err := exec.Command("curl", "-s", "ifconfig.me").Output()
	if err != nil {
		return "", fmt.Errorf("failed to get public IP: %v", err)
	}

	// Get the IPFS peer ID
	peerID, err := exec.Command("ipfs", "config", "Identity.PeerID").Output()
	if err != nil {
		return "", fmt.Errorf("failed to get IPFS peer ID: %v", err)
	}

	// Construct the bootstrap address
	bootstrapAddress := fmt.Sprintf("/ip4/%s/tcp/4001/p2p/%s", string(publicIP), string(peerID))
	return bootstrapAddress, nil
}
EOF

    # Create start.sh
    cat <<EOF > start.sh
#!/bin/bash

# Initialize IPFS if not already initialized
if [ ! -f /root/.ipfs/config ]; then
    ipfs init
fi

# Configure the bootstrap node
ipfs bootstrap rm --all
ipfs bootstrap add /ip4/0.0.0.0/tcp/4001/p2p/\$(ipfs config Identity.PeerID)

# Start IPFS daemon with PubSub enabled
ipfs daemon --enable-pubsub-experiment &

# Start the Go HTTP server
hs-connect
EOF

    # Make start.sh executable
    chmod +x start.sh
}

# Function to install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing Docker..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        echo "Docker installed successfully."
    else
        echo "Docker is already installed."
    fi
}

# Function to add the user to the docker group
add_user_to_docker_group() {
    if ! groups | grep -q '\bdocker\b'; then
        echo "Adding user to the 'docker' group..."
        sudo usermod -aG docker \$USER
        echo "User added to the 'docker' group. Please log out and log back in for the changes to take effect."
        echo "After logging back in, re-run this script to continue."
        exit 1
    else
        echo "User is already in the 'docker' group."
    fi
}

# Function to build and run the Docker container
build_and_run_container() {
    echo "Building Docker image 'hs-connect'..."
    docker build -t hs-connect .

    # Check if port 8080 is in use
    if is_port_in_use 8080; then
        kill_process_using_port 8080
    fi

    echo "Running Docker container..."
    docker run -d \
      --name hs-connect \
      -p 4001:4001 \
      -p 5001:5001 \
      -p 8080:8080 \
      -p 80:80 \
      hs-connect

    echo "Docker container 'hs-connect' is now running!"
    echo "Access the bootstrap information at: http://\$(curl -s ifconfig.me)/connect"
}

# Main script execution
echo "Starting setup..."

# Install Docker
install_docker

# Add user to the docker group
add_user_to_docker_group

# Create necessary files
create_files

# Build and run the Docker container
build_and_run_container

# Clean up
echo "Cleaning up temporary files..."
rm -rf /tmp/hs-connect

echo "Setup complete!"
