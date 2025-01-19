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
		fmt.Fprintf(w, `
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
`, bootstrapAddress)
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
