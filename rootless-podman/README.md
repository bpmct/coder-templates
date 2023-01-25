# Rootless podman on Kubernetes (no priviledged containers)

1) Create a device plugin

    ```sh
    cat <<EOF | kubectl create -f -
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
    name: fuse-device-plugin-daemonset
    namespace: kube-system
    spec:
    selector:
    matchLabels:
        name: fuse-device-plugin-ds
    template:
    metadata:
        labels:
        name: fuse-device-plugin-ds
    spec:
        hostNetwork: true
        containers:
        - image: soolaugust/fuse-device-plugin:v1.0
        name: fuse-device-plugin-ctr
        securityContext:
            allowPrivilegeEscalation: false
            capabilities:
            drop: ["ALL"]
        volumeMounts:
            - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
        volumes:
        - name: device-plugin
            hostPath:
            path: /var/lib/kubelet/device-plugins
        imagePullSecrets:
        - name: registry-secret
    EOF
    ```

1. Test with a sample pod

```sh
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-priv
  annotations:
    container.apparmor.security.beta.kubernetes.io/no-priv: "unconfined"
spec:
 containers:
   - name: no-priv
     image: quay.io/podman/stable
     args:
       - sleep
       - "1000000"
     securityContext:
       runAsUser: 1000
     resources:
       limits:
         github.com/fuse: 1
EOF
```

Label nodes

```sh
kubectl label nodes --all smarter-device-manager=enabled 
```