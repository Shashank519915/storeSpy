# RIP CV Runtime Base Image
# Ticket: RIP-0-051
# nvidia/cuda:12.1-runtime-ubuntu22.04 + OTel + non-root user

FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV OTEL_SERVICE_NAME=rip-edge
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.rip-system.svc.cluster.local:4317

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# OpenTelemetry auto-instrumentation (Python) — install as root before dropping privileges
RUN pip3 install --no-cache-dir opentelemetry-distro opentelemetry-exporter-otlp \
    && opentelemetry-bootstrap -a install

# Non-root user
RUN groupadd -r rip && useradd -r -g rip -u 10001 rip

WORKDIR /app

COPY infra/docker/base-cv-runtime/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown rip:rip /app/entrypoint.sh

USER rip

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/healthz || exit 1

EXPOSE 8080

CMD ["/app/entrypoint.sh"]
