#!/usr/bin/env bash
set -euo pipefail

# install_k3s.sh
# Usage:
#   sudo bash install_k3s.sh
#   sudo K3S_VERSION="v1.35.4+k3s1" bash install_k3s.sh

K3S_VERSION="${K3S_VERSION:-v1.35.4+k3s1}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.3.9}"

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root: sudo bash install_k3s.sh"
  exit 1
fi

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"

if [ -z "$TARGET_HOME" ]; then
  echo "could not determine home directory for user: $TARGET_USER"
  exit 1
fi

echo "**** install k3s ****"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -

echo "**** enable and restart k3s service ****"
systemctl enable k3s
systemctl restart k3s

echo "**** wait for node ready ****"
if ! k3s kubectl wait --for=condition=Ready node --all --timeout=60s >/dev/null 2>&1; then
  echo "k3s node did not become ready in time"
  exit 1
fi

k3s kubectl get nodes -o wide

echo "**** export kubeconfig ****"
mkdir -p "$TARGET_HOME/.kube"
if [ -f "$TARGET_HOME/.kube/config" ]; then
  cp "$TARGET_HOME/.kube/config" "$TARGET_HOME/.kube/config.bak.$(date +%Y%m%d%H%M%S)"
fi
cp /etc/rancher/k3s/k3s.yaml "$TARGET_HOME/.kube/config"
chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.kube/config"
# Replace localhost so kubectl works from host network interfaces too
HOST_IP="$(hostname -I | awk '{print $1}')"
if [ -n "$HOST_IP" ]; then
  sed -i "s/127.0.0.1/${HOST_IP}/" "$TARGET_HOME/.kube/config" || true
fi

echo "**** install kubectl wrapper ****"
cat >/usr/local/bin/kubectl <<'EOF'
#!/usr/bin/env bash
exec k3s kubectl "$@"
EOF
chmod +x /usr/local/bin/kubectl

echo "**** install helm ****"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "helm already installed"
fi

echo "**** install argocd cli ****"
if ! command -v argocd >/dev/null 2>&1; then
  OS="$(uname | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "unsupported arch: $ARCH"; exit 1 ;;
  esac
  curl -fsSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-${OS}-${ARCH}"
  chmod +x /usr/local/bin/argocd
else
  echo "argocd already installed"
fi

echo "**** setup kubectl completion ****"
touch "$TARGET_HOME/.bashrc"
if ! grep -q "kubectl completion bash" "$TARGET_HOME/.bashrc"; then
  echo "source <(kubectl completion bash)" >>"$TARGET_HOME/.bashrc"
  chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.bashrc"
fi

echo "**** done ****"
echo "kubeconfig: $TARGET_HOME/.kube/config"
echo "test: kubectl get nodes"
