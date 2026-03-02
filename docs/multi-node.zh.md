# 使用 Gthulhu 管理多節點策略

![Static Badge](https://img.shields.io/badge/version-v0.6.0-blue)

承續「使用 Web GUI 設定 scheduling policies」的內容，這裡將介紹如何使用 Gthulhu 管理多節點的 scheduling policies。
事實上，Gthulhu 的設計初衷就是為了管理多節點的 scheduling policies，所以在設定 Policy 時，Gthulhu 會自動將設定同步到所有節點上。

本節的驗證環境是一個包含兩個節點的 Kubernetes 叢集，分別是 myvm 和 d11nn。

```
$ kubectl get po --selector app.kubernetes.io/name=prometheus-node-exporter -o wide
NAME                                                   READY   STATUS    RESTARTS   AGE   IP           NODE    NOMINATED NODE   READINESS GATES
kube-prometheus-stack-prometheus-node-exporter-fdc7l   1/1     Running   1          44h   172.16.0.4   myvm    <none>           <none>
kube-prometheus-stack-prometheus-node-exporter-k8gg4   1/1     Running   0          50m   172.16.0.5   d11nn   <none>           <none>
```

參考上方的輸出，我們可以看到兩個節點上都部署了 Prometheus Node Exporter，分別是 myvm 和 d11nn。

接著，我們同樣透過 Web GUI 設定 scheduling policies，並且在設定完成後，確認兩個節點上的 scheduling policies 是否已經同步：

![alt text](./assets/multinode1.png)

接著我們可以觀察到確實兩個節點上的 scheduling policies 都已經同步了，這表示 Gthulhu 成功地將設定同步到所有節點上：

![alt text](./assets/multinode2.png)

![alt text](./assets/multinode3.png)