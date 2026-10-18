FROM python:3.12-slim
WORKDIR /app

# Retains standard system packages and runs as root to establish an unhardened baseline for size and CVE comparisons.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

EXPOSE 5000
CMD ["python", "app.py"]
