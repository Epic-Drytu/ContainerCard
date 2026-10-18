FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .

# Prevents pip from caching downloaded wheel archives to keep build layer overhead low.
# Installs application dependencies into a dedicated directory without altering system site-packages.
RUN pip install --no-cache-dir --target=/install -r requirements.txt

FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app

# Copies only the installed runtime packages into the image, omitting build utilities, pip, and compilation caches.
COPY --from=build --chown=nonroot:nonroot /install /site-packages
COPY --chown=nonroot:nonroot app.py .

ENV PYTHONPATH=/site-packages

# Distroless images execute as nonroot (UID 65532) by default; setting USER explicitly satisfies container scanners.
USER nonroot:nonroot

EXPOSE 5000
CMD ["app.py"]
