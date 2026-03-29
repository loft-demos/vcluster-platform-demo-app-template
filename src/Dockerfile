# syntax=docker/dockerfile:1.7
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder
ARG TARGETARCH
ARG TARGETOS
ARG IMAGE_TAG=""
WORKDIR /src
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w -X main.buildImageTag=${IMAGE_TAG}" -o /out/http-echo main.go

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /out/http-echo /http-echo
EXPOSE 8080
ENTRYPOINT ["/http-echo"]
