# Hardening Gthulhu Network Security with Istio Ambient Mode
## 前言

在 Gthulhu 架構中，scheduler / decision-maker 會接觸到核心排程資訊、節點程序狀態與控制面策略資料，權限明顯高於一般 Pod。這類元件一旦在 production 環境被入侵，攻擊者可利用橫向移動（lateral movement）逐步接近 MongoDB、Manager API 與節點關鍵服務，最終造成：

- 策略被竄改（例如排程策略、意圖分發結果）
- 控制面資訊外洩（租戶工作負載與節點拓樸）
- 服務降級或拒絕服務（DoS）
- 進一步擴大到整個叢集的權限濫用

因此，production 不應只依賴「服務可連通」的預設行為，而應同時實作：

- L4 網路隔離（NetworkPolicy，限制誰可以連到誰）
- L7 身分與請求條件控管（AuthorizationPolicy）
- 入口統一治理（Gateway API）

本文將示範如何在 Istio Ambient 模式下，將 Gthulhu 的網路暴露面縮到最小，降低高權限元件被濫用時的爆炸半徑。


##  安裝 istio
```bash
$ curl -L https://istio.io/downloadIstio | sh -
$ cd istio-1.29.1/
$ export PATH=$PWD/bin:$PATH
$ sudo install -m 0755 /home/<USERNAME>/istio-1.29.1/bin/istioctl /usr/local/bin/istioctl
```
- `<USERNAME>` 為你的使用者名稱

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

Kubernetes 預設是沒有安裝 Gateway API CRD 的，為確保 istio 能夠順利被安裝，需要先新增以下 CRD：
```bash
$ kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/experimental-install.yaml
```

完成後，使用 `istioctl` 安裝 istio，本文中安裝的是 Ambient mode，比起傳統的 istio sidecar 有更高的效能：
```bash
$ istioctl install --set profile=ambient --skip-confirmation
```

## 使用 Gateway API

為何建議使用 Gateway API，而不是直接用 NodePort 或 `kubectl port-forward`：

- **宣告式管理**：流量入口（Port、Path、Host、Backend）可用 YAML 版本化，方便 review 與 GitOps。
- **與平台整合更完整**：Istio 會根據 `Gateway`/`HTTPRoute` 自動建立與維護對應資料平面設定。
- **擴充性較好**：後續要加 TLS、多路由規則、灰度路由或多服務轉發時，不需改應用 Service 型別。
- **比 `port-forward` 更適合長期使用**：`port-forward` 偏向臨時除錯，會話中斷就失效，且不利團隊共用。
- **比直接暴露 NodePort 更乾淨**：NodePort 只解決「開一個 port」，而 Gateway API 能同時描述路由意圖與治理規則。

在任意目錄下新增 `gateway.yaml`：

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

套用設定：
```bash
$ kubectl apply -f gateway.yaml
```

確認 Gateway/Route 狀態：
```bash
$ kubectl get gateway,httproute -n default
```

確認 Istio Gateway 對應的 Service：
```bash
$ kubectl get svc -n default gthulhu-gw-istio
```

在本地端或沒有雲端 LoadBalancer 的環境下，`gthulhu-gw-istio` 常見會顯示：

- `TYPE=LoadBalancer`
- `EXTERNAL-IP=<pending>`
- `PORT(S)=80:30450/TCP`（數字可能不同）

這代表目前沒有可分配外部 IP 的 LB controller，但 Kubernetes 仍會配置 NodePort。
因此可以直接透過 `NodeIP:NodePort` 存取 API。

範例（請依你的實際 NodePort 調整）：
```bash
$ curl http://127.0.0.1:30450/health
$ curl http://<node-ip>:30450/health
```

做完這個步驟，你就能使用 `$ curl http://127.0.0.1:30450` 存取 Web GUI 囉！

## 實作 Network Policy

### L4 Network Policy

> 注意：NetworkPolicy 的實際封包阻擋需要 CNI 支援（例如 Calico、Cilium）。

為了降低橫向移動（lateral movement）風險，可以在 `default` namespace 套用以下 policy，限制只有 `gthulhu-manager` 可以連線到 `gthulhu-mongodb` 與 `gthulhu-scheduler`。

在任意目錄下新增 `gthulhu-network-policy.yaml`：

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

> 為何需要 `15008` 這條規則？
> 在 Ambient 模式下，workload 間流量會透過 ztunnel 的 HBONE（預設 `15008`）轉送。
> 若你對目標 Pod 套用了 ingress NetworkPolicy，除了應用 port（例如 MongoDB `27017`）外，也要放行 `15008`，否則可能出現連線 timeout。
> 換言之，如果不使用 Ambient Mode 其實不需要同時放行「應用埠 + `15008`」。

套用 policy：
```bash
$ kubectl apply -f gthulhu-network-policy.yaml
```

確認 policy：
```bash
$ kubectl get networkpolicy -n default
$ kubectl describe networkpolicy allow-only-manager-to-mongodb -n default
$ kubectl describe networkpolicy allow-only-manager-to-scheduler -n default
```

看見 policy 後，我們可以建立 test pod 驗證 policy 是否被 CNI 正確執行：

```bash
$ kubectl run np-allow-mgr --namespace default --restart=Never --rm -i --image=busybox:1.36 --labels='app.kubernetes.io/component=manager,app.kubernetes.io/instance=gthulhu,app.kubernetes.io/name=gthulhu' --command -- sh -c 'nc -z -w 3 gthulhu-mongodb 27017; echo ALLOW_TEST_EXIT=$?'
```

上面的命令為正面測試，輸出結果應該為 `0`，表示帶有 manager tag 的 Pod 應能夠存取 mongodb 服務。

反之，不帶有 manager tag 的 Pod 嘗試存取時，輸出結果應為 `1`：
```bash
$ kubectl run np-deny-other --namespace default --restart=Never --rm -i --image=busybox:1.36 --labels='app.kubernetes.io/component=attacker,app.kubernetes.io/instance=gthulhu,app.kubernetes.io/name=gthulhu' --command -- sh -c 'nc -z -w 3 gthulhu-mongodb 27017; echo DENY_TEST_EXIT=$?'
```


驗證重點：

- 從 `gthulhu-manager` Pod 連線到 MongoDB (`27017`) 與 Scheduler (`8080`) 應該成功。
- 從其他 Pod（例如非 manager）連線到上述兩個服務應該被拒絕。

### L7 Network Policy (AuthorizationPolicy)

在 Ambient mesh 中，可使用 Istio `AuthorizationPolicy` 做 L7 存取控制。
以下範例限制只有 `gthulhu-scheduler` 可存取 `gthulhu-manager` Pod：

1. 來源是 `gthulhu-scheduler`（ServiceAccount: `default/gthulhu`）

先啟用 namespace 的 Ambient 與 Waypoint（L7 規則生效必要條件）：

```bash
$ kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
$ istioctl waypoint apply -n default --enroll-namespace
$ kubectl label namespace default istio.io/use-waypoint=waypoint --overwrite
```

這三條指令的作用如下：

- `kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite`
  - 將 `default` namespace 標記為 Ambient mode，讓 namespace 內新建立的 Pod 走 ztunnel 資料平面。
  - `--overwrite` 代表如果原本有值就覆蓋，方便重複執行。

- `istioctl waypoint apply -n default --enroll-namespace`
  - 在 `default` namespace 建立 waypoint（`GatewayClass=istio-waypoint`）。
  - `--enroll-namespace` 會同時幫 namespace 設定 waypoint enrollment，讓服務流量可由 waypoint 進行 L7 policy 判斷。

- `kubectl label namespace default istio.io/use-waypoint=waypoint --overwrite`
  - 指定 `default` namespace 使用名為 `waypoint` 的 waypoint。
  - 若未指定或名稱不一致，L7 `AuthorizationPolicy` 可能不會在預期路徑生效。

可用以下命令快速確認是否設定完成：

```bash
$ kubectl get ns default -L istio.io/dataplane-mode,istio.io/use-waypoint
$ kubectl get gateway -n default waypoint
```

建議在上述設定後，重啟相關 workload 讓新 Pod 完整套用 Ambient：

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
> 備註：一旦目標 workload 上存在 `ALLOW` policy，未命中規則的請求會被拒絕。

若你要從 Gateway 入口限制「只有 Chrome 可進入 Web UI」，建議在 Gateway workload 使用下列 policy：

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

套用：
```bash
$ kubectl apply -f manager-authz-policy.yaml
```

套用生效後，檢查 Policy 是否已存在：
```bash
$ kubectl get authorizationpolicy.security.istio.io
NAME                                ACTION   AGE
gthulhu-gateway-allow-chrome-only   ALLOW    7m6s
manager-allow-scheduler-or-chrome   ALLOW    36m
```

驗證：

```bash
$ curl -A 'Safari/605.1.15' -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:30450/
403

$ curl -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36' -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:30450/
200
```




