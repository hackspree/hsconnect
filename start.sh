#!/bin/bash

# Initialize IPFS if not already initialized
if [ ! -f /root/.ipfs/config ]; then
    ipfs init
fi

# Configure the bootstrap node
ipfs bootstrap rm --all
ipfs bootstrap add /ip4/0.0.0.0/tcp/4001/p2p/$(ipfs config Identity.PeerID)

# Start IPFS daemon with PubSub enabled
ipfs daemon --enable-pubsub-experiment &

# Start the Go HTTP server
hs-connect
