# Concourse SSH Resource

Execute remote SSH commands or transfer files in Concourse CI pipelines.

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

  - name: upload-artifacts
    plan:
      - put: my-server
        params:
          files:
            - src: dist/*.tar.gz
              dest: /opt/releases/
            - src: config/
              dest: /etc/myapp/
              use_sudo: true       # optional, upload as root
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
| `command`     | Yes*     | Command to execute on remote server                   |
| `files`       | Yes*     | Array of file transfers (see below)                   |
| `use_sudo`    | No       | Execute command with sudo (default: false)            |
| `environment` | No       | Environment variables to set before executing command |

*Either `command` OR `files` is required (mutually exclusive).

#### File Transfer (`files`)

Each entry in the `files` array supports:

| Parameter  | Required | Description                                                    |
|------------|----------|----------------------------------------------------------------|
| `src`      | Yes      | Source path or glob pattern (relative to working directory)    |
| `dest`     | Yes      | Remote destination path (absolute)                             |
| `use_sudo` | No       | Upload with root permissions via temp + sudo mv (default: false) |

Features:
- Glob patterns (e.g., `dist/*.tar.gz`)
- Recursive directory upload
- Multiple file entries per request
- Sudo upload for root-owned destinations

## Behavior

- **`check`** *(unsupported)*: Returns empty array `[]`
- **`in`** *(unsupported)*: Creates empty directory, returns timestamp as version
- **`out`**: 
  - With `command`: Executes SSH command, fails build if command returns non-zero exit code
  - With `files`: Transfers files via SCP, fails build if transfer fails

Get host key: `ssh-keyscan -t rsa hostname.example.com`

## Docker Hub

[jaedle/concourse-ssh-resource](https://hub.docker.com/r/jaedle/concourse-ssh-resource)

Tag: `latest`

## Notes

- SSH key authentication only (no password support)
- Store SSH keys in Concourse credential manager: `((ssh-private-key))`
- Sudo requires NOPASSWD configuration on target server
- Host key checking disabled by default (enable with `host_key` parameter)
- File uploads use SCP for transfer
- Sudo uploads: files are uploaded to `/tmp` first, then moved with `sudo mv`
