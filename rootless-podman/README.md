# Rootless podman on Kubernetes (no priviledged containers)

## Setup your cluster

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

2. Label nodes

    ```sh
    kubectl label nodes --all smarter-device-manager=enabled 
    ```

3. For systems running SELinux (typically Fedora-, CentOS-, and Red Hat-based systems), please disable SELinux or set it to permissive mode.

## TODO

- [ ] Fix Ubuntu UID (only works as root)