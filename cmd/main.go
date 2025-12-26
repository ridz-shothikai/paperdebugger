package main

import (
	"fmt"
	"os"
	"paperdebugger/internal"
	"paperdebugger/internal/api"
	"paperdebugger/internal/libs/logger"
)

func main() {
	app := initializeAppOnly()
	port := getPort()
	app.Run(fmt.Sprintf(":%s", port))
}

// getPort returns the port to listen on, defaulting to 6060
// Cloud Run sets the PORT environment variable
func getPort() string {
	port := os.Getenv("PORT")
	if port == "" {
		port = "6060"
	}
	return port
}

// initializeAppOnly initializes the app without starting the server (for testing)
func initializeAppOnly() *api.Server {
	log := logger.GetLogger()
	app, err := internal.InitializeApp()
	if err != nil {
		log.Fatalf("[PAPERDEBUGGER] failed to initialize app: %v", err)
	}
	return app
}
