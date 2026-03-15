# Concourse SSH Resource

Execute remote SSH commands in Concourse CI pipelines.

## Quick Start

```yaml
resource_types:
  - name: ssh
    type: docker-image
    source:
      repository: jaedle/concourse-ssh-resource
      tag: latest

resources:
  - name: my-server
    type: ssh
    source:
      hostname: ((ssh-hostname))
      username: ((ssh-username))
      ssh_key: ((ssh-private-key))
      port: 22                    # optional, default 22
      host_key: ((ssh-host-key))  # optional, enables strict checking

jobs:
  - name: deploy
    plan:
      - put: my-server
        params:
          command: /opt/app/deploy.sh
          use_sudo: true           # optional
          environment:             # optional
            DEPLOY_ENV: production
```

## Configuration

### Source Parameters

| Parameter  | Required | Description                                                                                 |
|------------|----------|---------------------------------------------------------------------------------------------|
| `hostname` | Yes      | SSH server hostname or IP address                                                           |
| `username` | Yes      | SSH username                                                                                |
| `ssh_key`  | Yes      | Private SSH key content (multiline string)                                                  |
| `port`     | No       | SSH port (default: 22)                                                                      |
| `host_key` | No       | SSH host key for strict verification. If not provided, strict host key checking is disabled |

### `put` Parameters

| Parameter     | Required | Description                                           |
|---------------|----------|-------------------------------------------------------|
| `command`     | Yes      | Command to execute on remote server                   |
| `use_sudo`    | No       | Execute command with sudo (default: false)            |
| `environment` | No       | Environment variables to set before executing command |

## Behavior

- **`check`** *(unsupported)*: Returns empty array `[]`
- **`in`** *(unsupported)*: Creates empty directory, returns timestamp version
- **`out`**: Executes SSH command, fails build if command returns non-zero exit code

Get host key: `ssh-keyscan -t rsa hostname.example.com`

## Docker Hub

[jaedle/concourse-ssh-resource](https://hub.docker.com/r/jaedle/concourse-ssh-resource)

Tag: `latest`

## Notes

- SSH key authentication only (no password support)
- Store SSH keys in Concourse credential manager: `((ssh-private-key))`
- Sudo requires NOPASSWD configuration on target server
- Host key checking disabled by default (enable with `host_key` parameter)
