FROM python:3.11-slim

# Avoid Python buffering
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*
  
# Copy pyproject  
COPY pyproject.toml .  
  
# Install dependencies  
RUN pip install --upgrade pip && pip install .

# Copy project files
COPY . .

# Expose Jupyter port
EXPOSE 8888

# Start Jupyter
CMD ["--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]