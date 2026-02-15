# PostgreSQL for Hereya

A Hereya package that provides PostgreSQL database with seamless development-to-production deployment. Uses Docker containers for local development and automatically switches to [AWS Aurora PostgreSQL](https://github.com/hereya/aws-aurora-postgres) for production deployments.

## Overview

This package (`hereya/postgres`) provides a complete PostgreSQL solution that adapts to your environment:
- **Local Development**: Deploys PostgreSQL as a Docker container with instant startup
- **Production**: Automatically switches to AWS Aurora Serverless V2 for scalability and reliability
- **Data Persistence**: Optional persistent storage for local development
- **Secure Credentials**: Automatically generated database names and passwords

## Features

- 🚀 **Zero-config setup** - Works out of the box with sensible defaults
- 🔄 **Automatic environment switching** - Docker for development, AWS Aurora for production
- 💾 **Flexible data persistence** - Configure data storage location or use ephemeral containers
- 🔐 **Secure by default** - Random password generation with no hardcoded credentials
- 🎯 **Single configuration** - Manage both development and production settings in one place

## Prerequisites

### For Local Development
- Docker installed and running
- Hereya CLI installed
- Terraform (version 1.0+)

### For Production Deployment
- AWS account with appropriate permissions
- VPC with private subnets tagged with `Tier=private`
- AWS credentials configured

## Installation

```bash
# Add PostgreSQL to your project
hereya add hereya/postgres
```

This single command sets up both development and production database capabilities.

## Important: up vs deploy

- **`hereya up`**: Use for development and testing environments (local Docker containers)
- **`hereya deploy`**: Use only for production deployments (requires workspace created with `--deployment` flag)

The `deploy` command triggers the automatic switch to AWS Aurora PostgreSQL, while `up` always uses local Docker containers.

## Quick Start

### 1. Local Development

```bash
# Start PostgreSQL container
hereya up

# View connection details
hereya env

# Stop and remove container
hereya down
```

### 2. Production Deployment

```bash
# Create a production workspace with deployment flag
hereya workspace create prod --profile production --deployment

# Deploy to production (automatically uses AWS Aurora)
hereya deploy -w prod

# View production connection details
hereya env -w prod
```

## Configuration

Configure parameters in `hereyaconfig/hereyavars/hereya--postgres.yaml`.

**Important**: Use `hereya up` for development and testing workspaces. Use `hereya deploy` only for workspaces created with the `--deployment` flag.

### Development Parameters (Docker)

| Parameter | Type | Required | Description | Default |
|-----------|------|----------|-------------|---------|
| `port` | number | No | PostgreSQL port | Auto-assigned |
| `network_mode` | string | No | Docker network mode | `"bridge"` |
| `persist_data` | boolean | No | Enable data persistence | `true` |
| `data_path` | string | No | Host path for data persistence | Auto-generated |
| `docker_image` | string | No | Docker image to use | `"novopattern/postgres:14.9-alpine-pgvector"` |
| `dbname` | string | No | Fixed database name (random if not set) | Auto-generated |
| `hereyaDockerNetwork` | string | No | Docker network to connect the container to | `null` |
| `disable_network_advanced` | boolean | No | Skip Docker network configuration | `false` |

### Production Parameters (AWS Aurora)

When deployed, this package automatically uses `hereya/aws-aurora-postgres` with these parameters:

| Parameter | Type | Required | Description | Default |
|-----------|------|----------|-------------|---------|
| `minimum_acu` | number | No | Minimum Aurora Capacity Units | `0.5` |
| `maximum_acu` | number | No | Maximum Aurora Capacity Units | `4.0` |
| `db_version` | string | No | PostgreSQL engine version | `14.9` |

### Example Configuration

```yaml
# Development configuration
port: 5432
persist_data: true
data_path: "/Users/myuser/postgres-data"
---
# Staging profile
profile: staging
minimum_acu: 0.5
maximum_acu: 2.0
db_version: "14.9"
---
# Production profile
profile: production
minimum_acu: 4.0
maximum_acu: 32.0
db_version: "15.4"
```

## Outputs

The package exports these environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_URL` | Full connection string (localhost) | `postgresql://user:pass@localhost:5432/dbname` |
| `POSTGRES_ROOT_URL` | Root connection string (localhost) | `postgresql://postgres:pass@localhost:5432` |
| `HEREYA_DOCKER_POSTGRES_URL` | Full connection string (Docker network) | `postgresql://user:pass@container:5432/dbname` |
| `HEREYA_DOCKER_POSTGRES_ROOT_URL` | Root connection string (Docker network) | `postgresql://postgres:pass@container:5432` |
| `DBNAME` | Database name | `friendly-panda` |

Access these in your application:
```bash
# View all exported variables
hereya env

# Use in your application
export $(hereya env | xargs)
```

## Usage Examples

### Basic Development Setup

```bash
# Add PostgreSQL to your project
hereya add hereya/postgres

# Start local database
hereya up

# Connect using the exported URL
psql $POSTGRES_URL
```

### Development with Custom Data Path

```yaml
# hereyaconfig/hereyavars/hereya--postgres.yaml
persist_data: true
data_path: "/Users/myuser/project-data/postgres"
```

```bash
# Start with persistent storage
hereya up

# Data persists across container restarts
hereya down
hereya up  # Previous data is still available
```

### Multi-Environment Setup

```yaml
# hereyaconfig/hereyavars/hereya--postgres.yaml
# Development (default)
port: 5432
persist_data: false  # Ephemeral for development
---
# Testing profile
profile: testing
port: 5433  # Different port for testing
persist_data: true
---
# Production profile
profile: production
minimum_acu: 4.0
maximum_acu: 16.0
```

```bash
# Development
hereya up

# Testing environment (non-deployment)
hereya workspace create test --profile testing
hereya up -w test

# Production (requires deployment flag)
hereya workspace create prod --profile production --deployment
hereya deploy -w prod
```

### Flow Commands (Branch-based Development)

```bash
# Create feature branch
git checkout -b feature/new-feature

# Add PostgreSQL to branch workspace
hereya flow add hereya/postgres

# Start branch-specific database
hereya flow up

# Work on your feature...

# Clean up when done
hereya flow down
git checkout main
```

## Data Persistence

### How It Works

The package offers flexible data persistence options:

1. **Ephemeral** (`persist_data: false`): Data is lost when container stops
2. **Auto-generated Path** (`persist_data: true`, no `data_path`): Creates `./data/<dbname>`
3. **Custom Path** (`persist_data: true`, with `data_path`): Uses specified directory

### Managing Persistent Data

```bash
# View data location
docker inspect $(docker ps -q -f name=postgres) | grep -A 1 Mounts

# Backup data
docker exec $(docker ps -q -f name=postgres) pg_dump -U postgres $DBNAME > backup.sql

# Restore data
docker exec -i $(docker ps -q -f name=postgres) psql -U postgres $DBNAME < backup.sql
```

## Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Check what's using port 5432
lsof -i :5432

# Use a different port
echo "port: 5433" >> hereyaconfig/hereyavars/hereya--postgres.yaml
```

#### Docker Not Running
```bash
# Check Docker status
docker info

# Start Docker Desktop or Docker daemon
# On macOS: open -a Docker
# On Linux: sudo systemctl start docker
```

#### Data Persistence Issues
```bash
# Check permissions on data directory
ls -la /path/to/data

# Fix permissions
chmod 755 /path/to/data
```

#### Connection Refused
```bash
# Check container is running
docker ps | grep postgres

# Check logs
docker logs $(docker ps -q -f name=postgres)

# Verify network mode
docker inspect $(docker ps -q -f name=postgres) | grep NetworkMode
```

## Advanced Usage

### Custom Network Configuration

```yaml
# Use host network (Linux only)
network_mode: "host"
port: 5432
```

### Integration with Docker Compose

```yaml
# docker-compose.yml
services:
  app:
    build: .
    environment:
      - POSTGRES_URL=${POSTGRES_URL}
    external_links:
      - postgres
```

### Direct Terraform Usage

```bash
# Initialize Terraform
terraform init

# Apply with variables
terraform apply -var="port=5433" -var="persist_data=false"

# Destroy
terraform destroy
```

## Migration from Existing PostgreSQL

### From Docker PostgreSQL

```bash
# Export from existing container
docker exec old-postgres pg_dumpall -U postgres > dump.sql

# Import to Hereya PostgreSQL
hereya up
docker exec -i $(docker ps -q -f name=postgres) psql -U postgres < dump.sql
```

### From Cloud PostgreSQL

```bash
# Export from cloud database
pg_dump $OLD_DATABASE_URL > dump.sql

# Import to local development
hereya up
psql $POSTGRES_URL < dump.sql

# Deploy to production
hereya deploy -w prod
# Then migrate data to Aurora
```

## Best Practices

### Development
- Use ephemeral containers (`persist_data: false`) for testing
- Keep sensitive data out of version control
- Use different ports for multiple projects

### Production
- Always use profiles to separate environments
- Configure appropriate ACU limits for AWS Aurora
- Set up proper VPC and security groups
- Enable backups and monitoring

### Security
- Never commit `.env` files with credentials
- Use AWS Systems Manager for production secrets
- Regularly rotate database passwords
- Restrict network access in production

## Architecture Details

### Local Development Architecture
```
┌─────────────────┐
│   Application   │
└────────┬────────┘
         │
    POSTGRES_URL
         │
┌────────▼────────┐
│ Docker Container│
│   PostgreSQL    │
│   Latest Image  │
└────────┬────────┘
         │
   Optional Volume
         │
┌────────▼────────┐
│   Host Path     │
│  Data Storage   │
└─────────────────┘
```

### Production Architecture (via AWS Aurora)
```
┌─────────────────┐
│   Application   │
└────────┬────────┘
         │
    POSTGRES_URL
         │
┌────────▼────────┐
│  AWS Aurora     │
│  Serverless V2  │
│   PostgreSQL    │
└────────┬────────┘
         │
    Auto-scaling
         │
┌────────▼────────┐
│   AWS SSM       │
│ Parameter Store │
└─────────────────┘
```

## Related Packages

- [hereya/aws-aurora-postgres](https://github.com/hereya/aws-aurora-postgres) - Production deployment package (automatically used)

## Support

For issues or questions:
- Create an issue in the [package repository](https://github.com/hereya/postgres)
- Check the [Hereya documentation](https://docs.hereya.dev)

## License

MIT