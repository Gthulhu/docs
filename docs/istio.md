# Strengthening Gthulhu Service Security with Service Mesh

## Introduction

In the Gthulhu architecture, the scheduler / decision-maker can access kernel scheduling data, node process state, and control-plane strategy data, and therefore has significantly higher privileges than regular application pods. If these components are compromised in production, attackers can use lateral movement to progressively reach MongoDB, the Manager API, and critical node services, which can eventually lead to:

- Strategy tampering (for example, scheduling policies or intent distribution results)
- Control-plane information leakage (tenant workloads and node topology)
- Service degradation or denial of service (DoS)
- Further privilege abuse across the entire cluster

For this reason, production environments should not rely only on the default “service connectivity” behavior. You should implement all of the following together:

- L4 network isolation (NetworkPolicy: who can talk to whom)
- L7 identity and request-condition control (AuthorizationPolicy)
- Unified ingress governance (Gateway API)

This guide demonstrates how to minimize Gthulhu’s network exposure under Istio Ambient mode and reduce the blast radius if high-privilege components are abused.

## Install Istio
```bash
$ curl -L https://istio.io/downloadIstio | sh -
$ cd istio-1.29.1/
$ export PATH=$PWD/bin:$PATH
$ sudo install -m 0755 /home/<USERNAME>/istio-1.29.1/bin/istioctl /usr/local/bin/istioctl
```
- Replace `<USERNAME>` with your local username.

```bash
$ istioctl
Istio configuration command line utility for service operators to
debug and diagnose their Istio mesh.

Usage:
  istioctl [command]

Available Commands:
  admin                Manage control plane (istiod) configuration
  analyze              Analyze Istio configuration and print validation messages
  authz                (authz is experimental. Use `istioctl experimental authz`)
  bug-report           Cluster information and log capture support tool.
  completion           Generate the autocompletion script for the specified shell
  create-remote-secret Create a secret with credentials to allow Istio to access remote Kubernetes apiservers
  dashboard            Access to Istio web UIs
  experimental         Experimental commands that may be modified or deprecated
  help                 Help about any command
  install              Applies an Istio manifest, installing or reconfiguring Istio on a cluster.
  kube-inject          Inject Istio sidecar into Kubernetes pod resources
  manifest             Commands related to Istio manifests
  proxy-config         Retrieve information about proxy configuration from Envoy [kube only]
  proxy-status         Retrieves the synchronization status of each Envoy in the mesh
  remote-clusters      Lists the remote clusters each istiod instance is connected to.
  tag                  Command group used to interact with revision tags
  uninstall            Uninstall Istio from a cluster
  upgrade              Upgrade Istio control plane in-place
  validate             Validate Istio policy and rules files
  version              Prints out build version information
  waypoint             Manage waypoint configuration
  ztunnel-config       Update or retrieve current Ztunnel configuration.

Flags:
      --as string                   Username to impersonate for the operation. User could be a regular user or a service account in a namespace
      --as-group stringArray        Group to impersonate for the operation, this flag can be repeated to specify multiple groups.
      --as-uid string               UID to impersonate for the operation.
      --context string              Kubernetes configuration context
  -h, --help                        help for istioctl
  -i, --istioNamespace string       Istio system namespace (default "istio-system")
      --kubeclient-timeout string   Kubernetes client timeout as a time.Duration string, defaults to 15 seconds. (default "15s")
  -c, --kubeconfig string           Kubernetes configuration file
  -n, --namespace string            Kubernetes namespace
      --vklog Level                 number for the log level verbosity. Like -v flag. ex: --vklog=9

Additional help topics:
  istioctl options              Displays istioctl global options

Use "istioctl [command] --help" for more information about a command.
```

Gateway API CRDs are not installed in Kubernetes by default. To ensure Istio installs correctly, apply them first:
```bash
$ kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/experimental-install.yaml
```

Then install Istio with Ambient mode, which provides better performance than the traditional sidecar mode:
```bash
$ istioctl install --set profile=ambient --skip-confirmation
```

## Use Gateway API

Why use Gateway API instead of exposing NodePort directly or relying on `kubectl port-forward`:

- **Declarative management**: Ingress behavior (port/path/host/backend) is versioned in YAML and works well with review and GitOps.
- **Better platform integration**: Istio automatically creates and maintains matching dataplane configuration from `Gateway` / `HTTPRoute`.
- **Better scalability**: Adding TLS, route rules, canary traffic, or multi-service routing does not require changing Service types.
- **Better for long-term operations than `port-forward`**: `port-forward` is primarily for temporary debugging and is not stable for team-shared access.
- **Cleaner than exposing raw NodePort**: NodePort only opens a port, while Gateway API also defines routing intent and governance.

Create `gateway.yaml` in any directory:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gthulhu-gw
  namespace: default
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gthulhu-manager-route
  namespace: default
spec:
  parentRefs:
    - name: gthulhu-gw
  rules:
    - backendRefs:
        - name: gthulhu-manager
          port: 8080
```

Apply:
```bash
$ kubectl apply -f gateway.yaml
```

Check Gateway / Route status:
```bash
$ kubectl get gateway,httproute -n default
```

Check the Istio Gateway-backed Service:
```bash
$ kubectl get svc -n default gthulhu-gw-istio
```

In local or non-cloud environments without a cloud LoadBalancer, `gthulhu-gw-istio` often shows:

- `TYPE=LoadBalancer`
- `EXTERNAL-IP=<pending>`
- `PORT(S)=80:30450/TCP` (number may differ)

This means there is no LB controller to assign an external IP, but Kubernetes still allocates a NodePort.
So you can access the API through `NodeIP:NodePort`.

Example (replace with your actual NodePort):
```bash
$ curl http://127.0.0.1:30450/health
$ curl http://<node-ip>:30450/health
```

After this, you can use `$ curl http://127.0.0.1:30450` to access the Web GUI.

## Implement Network Policies

### L4 NetworkPolicy

> Note: Actual packet enforcement for Kubernetes NetworkPolicy depends on your CNI implementation (for example, Calico or Cilium).

To reduce lateral movement risk, apply the following policies in the `default` namespace so only `gthulhu-manager` can connect to `gthulhu-mongodb` and `gthulhu-scheduler`.

Create `gthulhu-network-policy.yaml` in any directory:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-only-manager-to-mongodb
  namespace: default
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: mongodb
      app.kubernetes.io/instance: gthulhu
      app.kubernetes.io/name: mongodb
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: manager
              app.kubernetes.io/instance: gthulhu
              app.kubernetes.io/name: gthulhu
      ports:
        - protocol: TCP
          port: 27017
        - protocol: TCP
          port: 15008
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-only-manager-to-scheduler
  namespace: default
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: scheduler
      app.kubernetes.io/instance: gthulhu
      app.kubernetes.io/name: gthulhu
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: manager
              app.kubernetes.io/instance: gthulhu
              app.kubernetes.io/name: gthulhu
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 15008
```

> Why is the `15008` rule required?
> In Ambient mode, workload-to-workload traffic is tunneled through ztunnel via HBONE (default `15008`).
> If you apply ingress NetworkPolicy on target pods, you must allow both the application port (for example, MongoDB `27017`) and `15008`; otherwise, requests may time out.
> In other words, if you are not using Ambient mode, you generally do not need to allow both “app port + `15008`”.

Apply policies:
```bash
$ kubectl apply -f gthulhu-network-policy.yaml
```

Check policies:
```bash
$ kubectl get networkpolicy -n default
$ kubectl describe networkpolicy allow-only-manager-to-mongodb -n default
$ kubectl describe networkpolicy allow-only-manager-to-scheduler -n default
```

Then create test pods to verify CNI enforcement:

```bash
$ kubectl run np-allow-mgr --namespace default --restart=Never --rm -i --image=busybox:1.36 --labels='app.kubernetes.io/component=manager,app.kubernetes.io/instance=gthulhu,app.kubernetes.io/name=gthulhu' --command -- sh -c 'nc -z -w 3 gthulhu-mongodb 27017; echo ALLOW_TEST_EXIT=$?'
```

The command above is a positive test. Expected output is `0`, meaning pods with manager labels can access MongoDB.

Negative test (without manager labels) should return `1`:
```bash
$ kubectl run np-deny-other --namespace default --restart=Never --rm -i --image=busybox:1.36 --labels='app.kubernetes.io/component=attacker,app.kubernetes.io/instance=gthulhu,app.kubernetes.io/name=gthulhu' --command -- sh -c 'nc -z -w 3 gthulhu-mongodb 27017; echo DENY_TEST_EXIT=$?'
```

Validation goals:

- Connection from `gthulhu-manager` to MongoDB (`27017`) and Scheduler (`8080`) should succeed.
- Connection from other pods (non-manager) to these services should be denied.

### L7 NetworkPolicy (AuthorizationPolicy)

In Ambient mesh, use Istio `AuthorizationPolicy` for L7 controls.
The following example allows only `gthulhu-scheduler` to access `gthulhu-manager`:

1. Source is `gthulhu-scheduler` (ServiceAccount: `default/gthulhu`)

First, enable Ambient and Waypoint for the namespace (required for L7 policy to take effect):

```bash
$ kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
$ istioctl waypoint apply -n default --enroll-namespace
$ kubectl label namespace default istio.io/use-waypoint=waypoint --overwrite
```

What these three commands do:

- `kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite`
  - Marks the `default` namespace as Ambient mode so newly created pods use ztunnel dataplane.
  - `--overwrite` ensures repeatable execution if the label already exists.

- `istioctl waypoint apply -n default --enroll-namespace`
  - Creates a waypoint in the `default` namespace (`GatewayClass=istio-waypoint`).
  - `--enroll-namespace` also enrolls the namespace so service traffic can be evaluated by waypoint for L7 policies.

- `kubectl label namespace default istio.io/use-waypoint=waypoint --overwrite`
  - Sets `waypoint` as the waypoint used by the `default` namespace.
  - If this is missing or the name does not match, L7 `AuthorizationPolicy` may not be enforced on the expected path.

Quick verification:

```bash
$ kubectl get ns default -L istio.io/dataplane-mode,istio.io/use-waypoint
$ kubectl get gateway -n default waypoint
```

After this setup, restart related workloads so new pods fully adopt Ambient:

```bash
$ kubectl rollout restart deploy/gthulhu-manager -n default
$ kubectl rollout restart statefulset/gthulhu-mongodb -n default
$ kubectl rollout restart daemonset/gthulhu-scheduler -n default
```

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: manager-allow-scheduler-or-chrome
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: gthulhu-manager
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/default/sa/gthulhu
      to:
        - operation:
            ports: ["8080"]
```
> Note: once an `ALLOW` policy exists for a workload, requests that do not match any rule are denied.

If you also want to allow only Chrome at Gateway ingress for the Web UI, use this policy on the Gateway workload:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: gthulhu-gateway-allow-chrome-only
  namespace: default
spec:
  selector:
    matchLabels:
      gateway.networking.k8s.io/gateway-name: gthulhu-gw
  action: ALLOW
  rules:
    - to:
        - operation:
            ports: ["80"]
      when:
        - key: request.headers[User-Agent]
          values:
            - "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/*"
```

Apply:
```bash
$ kubectl apply -f manager-authz-policy.yaml
```

After apply, confirm policies exist:
```bash
$ kubectl get authorizationpolicy.security.istio.io
NAME                                ACTION   AGE
gthulhu-gateway-allow-chrome-only   ALLOW    7m6s
manager-allow-scheduler-or-chrome   ALLOW    36m
```

Validation:

```bash
$ curl -A 'Safari/605.1.15' -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:30450/
403

$ curl -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36' -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:30450/
200
```
