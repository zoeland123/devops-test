# ---- Stage 1: build ----
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
ARG VERSION=dev
# CGO_ENABLED=0 -> binary statis
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" -o /out/app .

# ---- Stage 2: runtime ----
FROM scratch
COPY --from=build /out/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
