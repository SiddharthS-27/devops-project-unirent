# The api container: the backend app with the security and payments packages
# installed into it. Build with the repo root as the context:
#   docker build -f infra/docker/api.Dockerfile .
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN useradd --create-home --uid 10001 unirent
WORKDIR /src

# Packages install in dependency order. Editable installs let the dev profile
# bind-mount the source over them for hot reload.
COPY security/ security/
COPY payments/ payments/
COPY backend/ backend/
COPY infra/scripts/ infra/scripts/
COPY infra/seed/ infra/seed/
RUN for pkg in security payments backend; do \
      if [ -f "$pkg/pyproject.toml" ]; then pip install -e "./$pkg" || exit 1; fi; \
    done

USER unirent
WORKDIR /src/backend
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=5s --retries=6 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/readyz', timeout=4)"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
