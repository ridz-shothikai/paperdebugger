FROM golang:bookworm AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o dist/pd.exe cmd/main.go

FROM debian:bookworm-slim

# Install ca-certificates for HTTPS requests
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/dist/pd.exe .

# Cloud Run expects the service to listen on the PORT environment variable
# Default to 8080 if PORT is not set
ENV PORT=8080

EXPOSE 8080

CMD ["./pd.exe"]
