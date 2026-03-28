package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestComposeText(t *testing.T) {
	t.Parallel()

	if got := composeText("hello", "", ""); got != "hello" {
		t.Errorf("Wrong text without shared message: %q", got)
	}

	if got := composeText("hello", "", "ghcr.io/acme/guestbook:v1.2.3"); got != "hello\ndocker tag: v1.2.3" {
		t.Errorf("Wrong text with docker tag: %q", got)
	}

	if got := composeText("hello", "host-cluster ESO store", "ghcr.io/acme/guestbook:v1.2.3"); got != "hello\ndocker tag: v1.2.3\nshared config: host-cluster ESO store" {
		t.Errorf("Wrong text with shared message: %q", got)
	}
}

func TestParseImageTag(t *testing.T) {
	t.Parallel()

	tests := map[string]string{
		"":                                     "",
		"ghcr.io/acme/guestbook:v1.2.3":        "v1.2.3",
		"registry:5000/acme/guestbook:1":       "1",
		"ghcr.io/acme/guestbook":               "",
		"ghcr.io/acme/guestbook@sha256:abcdef": "sha256:abcdef",
	}

	for imageRef, want := range tests {
		if got := parseImageTag(imageRef); got != want {
			t.Errorf("parseImageTag(%q) = %q, want %q", imageRef, got, want)
		}
	}
}

func TestTextHandler(t *testing.T) {
	t.Parallel()
	r := newHandler("hello")
	req, _ := http.NewRequest("GET", "/", nil)
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)
	if resp.Code != http.StatusOK {
		t.Errorf("Wrong status code: %d", resp.Code)
	}
	if got := resp.Body.String(); got != "hello" {
		t.Errorf("Wrong response body: %q", got)
	}
}

func TestHealthHandler(t *testing.T) {
	t.Parallel()
	r := newHandler("hello")
	req, _ := http.NewRequest("GET", "/health", nil)
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)
	if resp.Code != http.StatusOK {
		t.Errorf("Wrong status code: %d", resp.Code)
	}
	if got := strings.TrimSpace(resp.Body.String()); got != `{"status":"OK"}` {
		t.Errorf("Wrong response body: %q", got)
	}
}

func TestFallbackHandler(t *testing.T) {
	t.Parallel()
	r := newHandler("hello")
	req, _ := http.NewRequest("GET", "/你好", nil)
	resp := httptest.NewRecorder()
	r.ServeHTTP(resp, req)
	if resp.Code != http.StatusOK {
		t.Errorf("Wrong status code: %d", resp.Code)
	}
	if got := resp.Body.String(); got != "hello" {
		t.Errorf("Wrong response body: %q", got)
	}
}
