# syntax=docker/dockerfile:1
FROM dunglas/frankenphp:latest-builder AS builder

# Install xcaddy from the official Caddy builder image
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

# Enable CGO for building with native extensions
ENV CGO_ENABLED=1 \
    XCADDY_SETCAP=1 \
    XCADDY_GO_BUILD_FLAGS="-ldflags '-w -s'"

# Build FrankenPHP with custom modules including Cloudflare DNS module
RUN xcaddy build \
    --output /usr/local/bin/frankenphp \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/dunglas/frankenphp=./ \
    --with github.com/dunglas/frankenphp/caddy=./caddy/ \
    --with github.com/dunglas/mercure/caddy \
    --with github.com/dunglas/vulcain/caddy

# Start with a clean stage to reduce final image size
FROM debian:bookworm-slim

# Install any necessary dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Copy the FrankenPHP binary from the builder stage
COPY --from=builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# Set up directory for server files and move FrankenPHP there
RUN mkdir -p /mnt/server/public \
    && mv /usr/local/bin/frankenphp /mnt/server/frankenphp \
    && setcap 'cap_net_bind_service=+ep' /mnt/server/frankenphp \
    && chmod +x /mnt/server/frankenphp

# Set work directory
WORKDIR /mnt/server

# Command to run when starting the container
CMD ["/mnt/server/frankenphp", "run"]
