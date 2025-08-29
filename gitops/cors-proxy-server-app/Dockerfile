# Use a lightweight Python base image
FROM python:3.9-slim-buster

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY app.py .

# Expose the port the Flask app will listen on
EXPOSE 8080

# Define the command to run the Flask application
# Using Gunicorn for a more robust production-ready server
# Install gunicorn first
RUN pip install gunicorn==20.1.0

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
