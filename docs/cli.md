# Using gthulhu-cli

![Static Badge](https://img.shields.io/badge/version-v0.6.0-blue)

Sometimes we need to test Gthulhu in an environment without a GUI. Although `curl` can help us interact with the Gthulhu API Server, it is still not intuitive enough.
To solve this, we provide a CLI tool.

## Install the CLI

Use the following commands to install `gthulhu-cli`:
```bash
$ cd Gthulhu
$ make cli
$ sudo cp gthulhu-cli /usr/bin
gthulhu-cli is a command-line tool for interacting with the Gthulhu
scheduler (Manager Mode). It can manage scheduling strategies, list nodes,
query pod-PID mappings, and inspect the BPF priority map.

Usage:
  gthulhu-cli [command]

Available Commands:
  auth         Authentication commands
  help         Help about any command
  nodes        Kubernetes node operations
  priority-map View the BPF priority map from gthulhu scheduler pods
  strategies   Manage scheduling strategies

Flags:
  -u, --api-url string      Gthulhu API server URL (default "http://127.0.0.1:8080")
  -h, --help                help for gthulhu-cli
      --kubeconfig string   Path to kubeconfig file (defaults to ~/.kube/config)
  -n, --namespace string    Kubernetes namespace for scheduler pods (default "default")
      --no-auth             Skip JWT authentication

Use "gthulhu-cli [command] --help" for more information about a command.
```
## Basic Operations

### Login with gthulhu-cli

Before using the CLI, run `gthulhu-cli auth` to let the CLI obtain authorization from the API server:

```bash
$ gthulhu-cli auth login -U admin@example.com -P your-password-here
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI2OTZmMzlkOWIxMmJlOGVjZmU5YTZkYzUiLCJuZWVkQ2hhbmdlUGFzc3dvcmQiOmZhbHNlLCJpc3MiOiJic3MtYXBpLXNlcnZlciIsInN1YiI6IjY5NmYzOWQ5YjEyYmU4ZWNmZTlhNmRjNSIsImV4cCI6MTc3MjAwMTYxNywibmJmIjoxNzcxOTkwODE3LCJpYXQiOjE3NzE5OTA4MTd9.Nk0WicHITDZHK6pGpN92skKNcThZypxFv51dRaLSa1WlDrVt-_dCTMxz1plwgm8TZNU-doBpEhihfBIQQsesKY_JVPB-prVdPL77In2ThnYOe6XTZZqk6zIEoAjz0b3-933na6Pv7-IWpuc6TZxE0oVaDTt01Ovz8-lHSkJJfqJmb0nEqliODvlMvnnPy-DA-XonZlXNSW_8-5JUuZ59ZwOvlofkCNglBEUI6TUsjmQUhznbbl3r3SyL1Wthh_0CZHlxcXwWV_hxzNFsFDMbyaltqM5BVUTZAQR94-9vol7pvTLujIpiLcaUQ0XKwNEPzZUYLMQlDdPGxcgJmx4ydPqCKiAbf3x2tNMJZge2spHgtPZWGjNWVE45RzLRHi7sBB5ufGyNcSH4JUnfVjKEC3JrsR1VfHsZxwurc7XJ8vcnBN1sMuupsbS4kTVjIg13zGOLPEAjlPJMDuJ8VoSfJgWm83dV6LKvrwsnb1K4L-vjptpBsRnbDXuy4YWtgC3wuCSr4159yJs5e5w-T_YmMFsikNEfxGfALJOyI1aKcCVT8Jt90OdMAhxj3mFkXWd3M6zabbXJx8hVNudzm4YVcGhaDJ9FX8PuHTG4oRdfYRfpzwGkgAxzWpJGfmRyS7HrvLZJMiLasWDS_9t7aO1DqEEGOb9z4WGS4KP4uO6qneg"
  },
  "timestamp": "2026-02-25T03:40:17Z"
}
```

After that, you can start interacting with Gthulhu using the CLI.

### View the BPF Priority Task Map

First, check which priority tasks exist on each node:

```bash
$ gthulhu-cli priority-map
=== Node: myvm | Pod: gthulhu-scheduler-lj72r ===
--- Map: priority_tasks ---
[{
        "key": 3707204,
        "value": 20000000
    },{
        "key": 3708841,
        "value": 20000000
    },{
        "key": 3709000,
        "value": 20000000
    }
]

--- Map: priority_tasks_ ---
[{
        "key": 3709000,
        "value": 10
    },{
        "key": 3708841,
        "value": 10
    },{
        "key": 3707204,
        "value": 10
    }
]

=== Node: d11nn | Pod: gthulhu-scheduler-n94b2 ===
--- Map: priority_tasks ---
[{
        "key": 3120275,
        "value": 20000000
    }
]

--- Map: priority_tasks_ ---
[{
        "key": 3120275,
        "value": 10
    }
]
```

- `Map: priority_tasks` is the BPF priority task map in the gthulhu scheduler pod. The key is PID, and the value is allocated CPU time.
- `Map: priority_tasks_` is the BPF priority task map in the gthulhu scheduler pod. The key is PID, and the value is priority level.

### Query Existing Scheduling Strategies

```bash
$ gthulhu-cli strategies list
{
  "success": true,
  "data": {
    "strategies": [
      {
        "id": "699c164f270f44f24b745842",
        "priority": 10,
        "executionTime": 20000000,
        "commandRegex": ".*",
        "k8sNamespace": [
          "default"
        ],
        "labelSelectors": [
          {
            "key": "app.kubernetes.io/name",
            "value": "prometheus"
          }
        ],
        "strategyNamespace": "default"
      },
      {
        "id": "699ec3af5ab0069a79ccb0fa",
        "priority": 9,
        "executionTime": 20000000,
        "commandRegex": ".*",
        "k8sNamespace": [
          "default"
        ],
        "labelSelectors": [
          {
            "key": "app.kubernetes.io/name",
            "value": "prometheus-node-exporter"
          }
        ],
        "strategyNamespace": "default"
      }
    ]
  },
  "timestamp": "2026-03-02T07:07:12Z"
}
```

### Node Operations

Query nodes in the current cluster:

```bash
$ gthulhu-cli nodes list
{
  "success": true,
  "data": {
    "nodes": [
      {
        "name": "d11nn",
        "status": "Ready"
      },
      {
        "name": "myvm",
        "status": "Ready"
      }
    ]
  },
  "timestamp": "2026-03-02T07:09:02Z"
}
```

Query pod and PID mappings on a specific node:

```bash
$ gthulhu-cli nodes pids --node-id myvm
{
  "success": true,
  "data": {
    "node_id": "myvm",
    "node_name": "gthulhu-scheduler-vv8gn",
    "pods": [
      {
        "pod_id": "",
        "pod_uid": "fde8ba27-1b70-4f6f-9a9f-0eb27e578164",
        "processes": [
          {
            "pid": 3707232,
            "ppid": 3707143,
            "command": "pause",
            "container_id": ""
          },
          {
            "pid": 3707472,
            "ppid": 3707143,
            "command": "hostpath-provis",
            "container_id": ""
          }
        ]
      },
      // ...
    ]
    },
    "timestamp": "2026-03-02T07:09:45Z"
}
```