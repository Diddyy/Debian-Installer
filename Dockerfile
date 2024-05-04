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
    # Add extra Caddy modules here if needed

# Runtime stage
FROM dunglas/frankenphp AS runner

# Ensure the directory /mnt/server exists
RUN mkdir -p /mnt/server

# Replace the official FrankenPHP binary with the custom built one
COPY --from=builder /usr/local/bin/frankenphp /mnt/server/frankenphp

# Ensure proper permissions and capabilities
RUN setcap 'cap_net_bind_service=+ep' /mnt/server/frankenphp
