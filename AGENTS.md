# AGENTS.md

## Project Overview

Concourse CI resource for executing remote SSH commands.

## Development

### Prerequisites

- Docker
- Bash

### Testing

All tests are integration tests that execute real SSH commands against a containerized SSH server.

```bash
# Run all integration tests
./test/run_integration_tests.sh

# Or manually with docker-compose
cd test
docker-compose up --abort-on-container-exit --build
```

### Building

```bash
# Build Docker image locally
docker build -t concourse-ssh-resource .
```

### Testing Locally

To test the resource scripts manually:

```bash
# Test check
echo '{}' | docker run --rm -i concourse-ssh-resource /opt/resource/check

# Test in
echo '{"source":{}}' | docker run --rm -i concourse-ssh-resource /opt/resource/in /tmp

# Test out (requires actual SSH server)
echo '{"source":{"hostname":"...","username":"...","ssh_key":"..."},"params":{"command":"echo hello"}}' | \
  docker run --rm -i concourse-ssh-resource /opt/resource/out /tmp
```

## Project Structure

```
/
├── assets/              # Concourse resource scripts
│   ├── check           # No-op (returns empty array)
│   ├── in              # No-op (returns empty version)
│   └── out             # SSH command execution
├── test/               # Integration tests
│   ├── ssh-server/     # Test SSH server container
│   ├── tests/          # Test scripts
│   └── docker-compose.yml
├── .github/workflows/  # CI/CD pipeline
├── Dockerfile          # Resource container image
├── README.md           # User documentation
└── AGENTS.md           # This file
```

## Resource Behavior

### check
- Returns empty array `[]`
- No version tracking

### in
- Creates empty destination directory
- Returns version with timestamp
- No actual SSH connection

### out
- Connects to SSH server using provided credentials
- Executes command remotely
- Returns exit code 0 on success
- **Fails with non-zero exit code** if remote command fails
- Supports:
  - Custom port
  - Sudo execution
  - Environment variables
  - Host key verification (optional)

## Release Process

Releases are automated via GitHub Actions:

1. Push to `main`/`master` → runs tests, builds image
2. Push tag `v*` → runs tests, builds image, pushes to Docker Hub as `latest`

### Manual Release

```bash
# Create and push tag
git tag v1.0.0
git push origin v1.0.0
```

Docker image: `jaedle/concourse-ssh-resource:latest`

## Important Notes

- Resource fails if SSH command returns non-zero exit code
- Host key checking disabled by default (enable with `host_key` parameter)
- Sudo commands use `NOPASSWD` (configure target server accordingly)
- All scripts use `set -euo pipefail` for strict error handling
