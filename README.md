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
          dir:    /opt/app         # optional
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

  - name: fetch-status
    plan:
      - get: my-server
        params:
          files:
            - src: /opt/app/status.json
              dest: reports/
            - src: /var/log/deploy.log
              dest: .
              use_sudo: true
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

| Parameter     | Required | Description                                                                                    |
|---------------|----------|------------------------------------------------------------------------------------------------|
| `command`     | Yes*     | Command to execute on remote server                                                            |
| `files`       | Yes*     | Array of file transfers (see below)                                                            |
| `dir`         | No       | Remote directory to change into before executing `command` (fails if directory does not exist) |
| `use_sudo`    | No       | Execute command with sudo (default: false)                                                     |
| `environment` | No       | Environment variables to set before executing command                                          |

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

### `get` Parameters

`get` now requires `params.files`.

| Parameter  | Required | Description |
|------------|----------|-------------|
| `files`    | Yes      | Array of remote files to download |

Each entry in `files` supports:

| Parameter  | Required | Description |
|------------|----------|-------------|
| `src`      | Yes      | Absolute remote file path |
| `dest`     | Yes      | Relative local directory inside artifact output |
| `use_sudo` | No       | Read file via sudo temp-copy flow before download (default: false) |

Rules:
- `src` must be absolute
- `dest` must be relative
- `dest` may be `.`
- `dest` may contain nested relative directories
- `dest` must not escape artifact directory after normalization
- Downloaded file always keeps remote basename
- Two entries resolving to same local output path fail before transfer starts

## Behavior

- **`check`**: Returns single fresh version with random `uuid` on each invocation
- **`in`**:
  - Requires `params.files`
  - Downloads each remote file into `<artifact-dir>/<dest>/<basename(src)>`
  - With `use_sudo: true`, copies remote file into temporary `/tmp/concourse-ssh-resource-in-*` path, downloads it, then removes temp path
  - Fails on invalid `params.files`, duplicate local targets, SSH/auth errors, remote read errors, or local copy errors
  - Returns timestamp version plus metadata for hostname, file count, and downloaded file list
  - If download succeeds but remote temp cleanup fails, prints warning to stderr and still succeeds
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
- `get` without `params.files` now fails
- `get` downloads remote files only; no directory fetch or globbing contract
