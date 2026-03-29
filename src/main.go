package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

var buildImageTag string

func main() {
	text := flag.String("text", "", "text to put on the webpage")
	addr := flag.String("addr", ":8080", "address to listen on")
	flag.Parse()

	if *text == "" {
		log.Fatal("--text option is required!")
	}

	srv := http.Server{
		Addr:    *addr,
		Handler: newHandler(composeText(*text, os.Getenv("DEMO_SHARED_MESSAGE"), os.Getenv("DEMO_IMAGE"), buildImageTag)),
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server listen failed: %s\n", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %s\n", err)
	}

	log.Println("Server exiting")
}

func composeText(text, sharedMessage, imageRef, fallbackTag string) string {
	lines := []string{text}

	if tag := imageTag(imageRef, fallbackTag); tag != "" {
		lines = append(lines, "docker tag: "+tag)
	}

	if sharedMessage != "" {
		lines = append(lines, "shared config: "+sharedMessage)
	}

	return strings.Join(lines, "\n")
}

func imageTag(imageRef, fallbackTag string) string {
	if tag := parseImageTag(imageRef); tag != "" {
		return tag
	}

	return strings.TrimSpace(fallbackTag)
}

func parseImageTag(imageRef string) string {
	imageRef = strings.TrimSpace(imageRef)
	if imageRef == "" {
		return ""
	}

	if digestIndex := strings.Index(imageRef, "@"); digestIndex >= 0 {
		return imageRef[digestIndex+1:]
	}

	lastSlash := strings.LastIndex(imageRef, "/")
	lastColon := strings.LastIndex(imageRef, ":")
	if lastColon > lastSlash {
		return imageRef[lastColon+1:]
	}

	return ""
}

func newHandler(text string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(map[string]string{"status": "OK"}); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte(text))
	})
	return mux
}
