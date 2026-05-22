#!/usr/bin/env bash
set -euo pipefail

APT_LOCK_TIMEOUT="${APT_LOCK_TIMEOUT:-600}"

apt_update() {
  for i in $(seq 1 30); do
    if apt-get -o Dpkg::Lock::Timeout="$APT_LOCK_TIMEOUT" update; then
      return 0
    fi
    echo "apt-get update failed; retry $i/30"
    sleep 10
  done
  return 1
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Lock::Timeout="$APT_LOCK_TIMEOUT" install -y "$@"
}

# install_k3s.sh
# Usage:
#   sudo bash install_k3s.sh
#   sudo K3S_VERSION="v1.31.4+k3s1" bash install_k3s.sh

K3S_VERSION="${K3S_VERSION:-v1.35.4+k3s1}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.3.9}"

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root: sudo bash install_k3s.sh"
  exit 1
fi

if id ubuntu >/dev/null 2>&1; then
  TARGET_USER="${SUDO_USER:-ubuntu}"
else
  TARGET_USER="${SUDO_USER:-$(id -un)}"
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"

if [ -z "$TARGET_HOME" ]; then
  echo "could not determine home directory for user: $TARGET_USER"
  exit 1
fi

echo "**** install dependencies ****"
apt_update
apt_install curl ca-certificates

echo "**** enable SSM agent (best effort, no SSH needed) ****"
if ! systemctl status amazon-ssm-agent >/dev/null 2>&1; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) SSM_DEB_ARCH="amd64" ;;
    aarch64|arm64) SSM_DEB_ARCH="arm64" ;;
    *) SSM_DEB_ARCH="" ;;
  esac

  if [ -n "$SSM_DEB_ARCH" ]; then
    TMPDIR="$(mktemp -d)"
    curl -fsSL "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_${SSM_DEB_ARCH}/amazon-ssm-agent.deb" -o "$TMPDIR/amazon-ssm-agent.deb" || true
    if [ -s "$TMPDIR/amazon-ssm-agent.deb" ]; then
      dpkg -i "$TMPDIR/amazon-ssm-agent.deb" || apt_install -f
      systemctl enable --now amazon-ssm-agent || true
    fi
    rm -rf "$TMPDIR"
  fi
fi

echo "**** setup swap for small EC2 instance ****"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

free -h

echo "**** install k3s ****"
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644 --tls-san=${EXPECTED_PUBLIC_IP}" \
  sh -

echo "**** enable and restart k3s service ****"
systemctl enable k3s
systemctl restart k3s

echo "**** wait for node ready, best effort ****"
for i in $(seq 1 30); do
  if k3s kubectl get nodes -o wide >/tmp/k3s-nodes.log 2>&1; then
    cat /tmp/k3s-nodes.log
    echo "k3s node is reachable"
    break
  fi

  echo "waiting for kubernetes api... attempt $i"
  cat /tmp/k3s-nodes.log || true
  sleep 10
done

k3s kubectl get nodes -o wide || true

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

echo "**** prefer public API endpoint in kubeconfig (best effort) ****"
EXPECTED_PUBLIC_IP="${EXPECTED_PUBLIC_IP:-}"
if [ -n "$EXPECTED_PUBLIC_IP" ]; then
  echo "expected public ip: $EXPECTED_PUBLIC_IP"

  # IMDSv2 token (best-effort)
  IMDS_TOKEN="$(curl -fsSL -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)"

  for i in $(seq 1 60); do
    if [ -n "$IMDS_TOKEN" ]; then
      META_PUBLIC_IP="$(curl -fsSL -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
    else
      META_PUBLIC_IP="$(curl -fsSL http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
    fi

    if [ "$META_PUBLIC_IP" = "$EXPECTED_PUBLIC_IP" ]; then
      echo "metadata public ip matches expected"
      break
    fi

    echo "waiting for EIP association... attempt $i (metadata: ${META_PUBLIC_IP:-n/a})"
    sleep 5
  done

  sed -i "s#server: https://.*:6443#server: https://${EXPECTED_PUBLIC_IP}:6443#g" "$TARGET_HOME/.kube/config" || true
fi

echo "**** publish kubeconfig to SSM Parameter Store (optional) ****"
AWS_REGION="${AWS_REGION:-}"
KUBECONFIG_SSM_PARAMETER_NAME="${KUBECONFIG_SSM_PARAMETER_NAME:-}"

if [ -n "$AWS_REGION" ] && [ -n "$KUBECONFIG_SSM_PARAMETER_NAME" ]; then
  echo "publishing kubeconfig to: $KUBECONFIG_SSM_PARAMETER_NAME (region: $AWS_REGION)"
  apt_update
  if ! command -v aws >/dev/null 2>&1; then
    TMPDIR="$(mktemp -d)"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPDIR/awscliv2.zip"
    apt_install unzip
    unzip -q "$TMPDIR/awscliv2.zip" -d "$TMPDIR"
    "$TMPDIR/aws/install"
    rm -rf "$TMPDIR"
  fi

  echo "checking aws identity (should be instance profile)"
  aws sts get-caller-identity --region "$AWS_REGION" || true

  aws ssm put-parameter \
    --name "$KUBECONFIG_SSM_PARAMETER_NAME" \
    --type SecureString \
    --overwrite \
    --value "$(cat "$TARGET_HOME/.kube/config")" \
    --region "$AWS_REGION"

  echo "kubeconfig published to SSM successfully"
else
  echo "SSM publish skipped (AWS_REGION or KUBECONFIG_SSM_PARAMETER_NAME missing)"
fi

echo "**** verify kubectl ****"
command -v kubectl || true
kubectl version --client=true || true

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
echo "target user: $TARGET_USER"
echo "kubeconfig: $TARGET_HOME/.kube/config"
echo "test: kubectl get nodes"