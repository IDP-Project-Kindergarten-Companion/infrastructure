# Infrastructure Documentation

This is an overview of the infrastructure components used in this project.

## Components

### 1. Dockerfiles
- Contains the necessary Dockerfiles to build and run the application.
- Each service has its own Dockerfile for containerization.

### 2. MongoDB Setup
- MongoDB is used as the primary database.
- Configuration files and scripts for setting up MongoDB are included.
- Ensure the database container is running before starting the application.

### 3. Portainer
- Portainer is used for managing Docker containers.
- Provides a user-friendly interface for monitoring and managing the infrastructure.
- Access Portainer at `http://localhost:<port>` after setup.
