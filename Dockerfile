# syntax=docker/dockerfile:1
FROM dunglas/frankenphp AS builder

LABEL author="Josh" maintainer="Diddyy@users.noreply.github.com"
LABEL org.opencontainers.image.source="https://github.com/Diddyy/Debian-Installer"
LABEL org.opencontainers.image.licenses=MIT

# Install Go for building Caddy
RUN wget https://golang.org/dl/go1.22.2.linux-amd64.tar.gz \
    && tar -xvf go1.22.2.linux-amd64.tar.gz \
    && mv go /usr/local \
    && rm go1.22.2.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# Install xcaddy
RUN curl -sSL "https://github.com/caddyserver/xcaddy/releases/download/v0.4.0/xcaddy_0.4.0_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin

# Build custom Caddy with Cloudflare DNS module
RUN CGO_ENABLED=1 XCADDY_GO_BUILD_FLAGS="-ldflags '-w -s'" \
    xcaddy build \
    --output /usr/local/bin/frankenphp \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/dunglas/frankenphp/caddy \
    --with github.com/dunglas/mercure/caddy \
    --with github.com/dunglas/vulcain/caddy

# Runtime stage
FROM dunglas/frankenphp AS runtime

# Copy the binaries from the build stage
COPY --from=builder /usr/local/bin/caddy /usr/local/bin/caddy
COPY --from=builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# Set capabilities to allow binding to well-known ports
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/caddy \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/frankenphp
