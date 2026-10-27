# The test-runner and razorpay-sim containers: the suites in tests/ and the simulator.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN useradd --create-home --uid 10001 unirent && mkdir /results && chown unirent /results
WORKDIR /tests
COPY tests/requirements.txt .
RUN pip install -r requirements.txt
COPY tests/ .
USER unirent
CMD ["pytest", "-q"]
