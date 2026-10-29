# The workers container: outbox relay, consumers, timer runner.
#   docker build -f infra/docker/workers.Dockerfile .
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN useradd --create-home --uid 10001 unirent
WORKDIR /src
COPY workers/ workers/
RUN pip install -e ./workers

USER unirent
WORKDIR /src/workers
EXPOSE 9100
HEALTHCHECK --interval=10s --timeout=5s --retries=6 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:9100/metrics', timeout=4)"
STOPSIGNAL SIGTERM
CMD ["unirent-workers"]
