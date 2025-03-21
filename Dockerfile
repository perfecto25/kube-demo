# Use official Python runtime as base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements file
COPY api_gw/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY api_gw/main.py .

# Expose port 8500
EXPOSE 8500

# Run the application
CMD ["python", "main.py"]