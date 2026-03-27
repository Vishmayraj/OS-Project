FROM python:3.11-slim

WORKDIR /app

COPY app.py .

RUN pip install flask --no-cache-dir && apt-get update && apt-get install -y iputils-ping && rm -rf /var/lib/apt/lists/*

# Expose port
EXPOSE 5000

# ⚠️  Run as root intentionally — part of the vulnerability demo
CMD ["python", "app.py"]

