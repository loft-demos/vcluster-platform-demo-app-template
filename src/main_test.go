package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestComposeText(t *testing.T) {
	t.Parallel()

	if got := composeText("hello", ""); got != "hello" {
		t.Errorf("Wrong text without shared message: %q", got)
	}

	if got := composeText("hello", "host-cluster ESO store"); got != "hello\nshared config: host-cluster ESO store" {
		t.Errorf("Wrong text with shared message: %q", got)
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
