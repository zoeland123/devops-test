package main

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHelloHandler(t *testing.T) {
	version = "test"
	rec := httptest.NewRecorder()
	helloHandler(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != 200 {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "version=test") {
		t.Fatalf("unexpected body: %q", rec.Body.String())
	}
}
