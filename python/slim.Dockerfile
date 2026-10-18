FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .

# Prevents pip from caching downloaded package tarballs and wheels in the image layer since installation runs once.
RUN pip install --no-cache-dir --prefix=/home/appuser/.local -r requirements.txt

FROM python:3.12-slim
WORKDIR /app

RUN useradd -m appuser
COPY --from=build --chown=appuser:appuser /home/appuser/.local /home/appuser/.local
COPY --chown=appuser:appuser app.py .

ENV PATH=/home/appuser/.local/bin:$PATH
USER appuser

EXPOSE 5000
CMD ["python", "app.py"]
