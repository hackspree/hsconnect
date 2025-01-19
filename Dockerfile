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
RUN apt-get update && \
    apt-get install -y wget curl && \
    rm -rf /var/lib/apt/lists/*

# Install IPFS
RUN wget https://dist.ipfs.tech/kubo/v0.23.0/kubo_v0.23.0_linux-amd64.tar.gz && \
    tar -xvzf kubo_v0.23.0_linux-amd64.tar.gz && \
    cd kubo && \
    bash install.sh && \
    cd .. && \
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
