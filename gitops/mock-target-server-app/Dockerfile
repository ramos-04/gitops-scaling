# Use a lightweight Node.js base image
FROM node:20-alpine

# Set the working directory in the container
WORKDIR /app

# Install json-server globally
RUN npm install -g json-server

# Copy the mock data file into the container
COPY db.json /app/db.json

# Expose the port json-server will listen on
EXPOSE 3000

# Command to run json-server
# --host 0.0.0.0 makes it listen on all interfaces
# --watch db.json tells it to use our mock data file
CMD ["json-server", "--host", "0.0.0.0", "--watch", "db.json", "--port", "3000"]
