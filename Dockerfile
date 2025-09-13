FROM node:24-slim

# Install Python 3 and pip
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 \
       python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first for better layer caching
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . /app

# Expose the default API port
EXPOSE 8000

# Run the FastAPI server
ENTRYPOINT ["python3", "run.py", "--host", "0.0.0.0", "--port", "8000"]
