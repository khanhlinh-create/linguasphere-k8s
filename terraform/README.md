# Hướng dẫn triển khai

## Yêu cầu

- Terraform >= 1.6.0
- AWS CLI v2
- kubectl
- SSH key pair tại `~/.ssh/linguasphere-k3s-key`

---

## Bước 1 — Đăng nhập AWS qua IAM SSO

```bash
aws configure sso
```

Điền thông tin khi được hỏi:

```
SSO session name: linguasphere
SSO start URL: https://<your-sso-domain>.awsapps.com/start
SSO region: ap-southeast-2
SSO registration scopes: sso:account:access
```

Sau khi trình duyệt mở ra, đăng nhập và chọn account + role. Rồi hoàn tất cấu hình:

```
CLI default client Region: ap-southeast-2
CLI default output format: json
CLI profile name: linguasphere-dev
```

Đăng nhập (chạy mỗi khi token hết hạn):

```bash
aws sso login --profile linguasphere-dev
export AWS_PROFILE=linguasphere-dev
```

Kiểm tra:

```bash
aws sts get-caller-identity
```

---

## Bước 2 — Tạo secret Grafana trên AWS

```bash
aws secretsmanager create-secret \
  --name /linguasphere/dev/grafana-admin \
  --secret-string '{"password":"your_password"}' \
  --region ap-southeast-2
```

> Chỉ chạy lần đầu. Nếu đã có rồi thì bỏ qua.

---

## Bước 3 — Khởi tạo Terraform

```bash
terraform init
```

---

## Bước 4 — Triển khai hạ tầng (VPC + EC2 + k3s)

```bash
terraform apply
```

Đợi **3–5 phút** để EC2 bootstrap xong. Kiểm tra bằng cách vào AWS Console → Systems Manager → Parameter Store → `/linguasphere/dev/kubeconfig`, khi value bắt đầu bằng `apiVersion: v1` là xong.

---

## Bước 5 — Lấy kubeconfig về máy

```bash
mkdir -p ~/.kube
aws ssm get-parameter \
  --region ap-southeast-2 \
  --name "/linguasphere/dev/kubeconfig" \
  --with-decryption \
  --query Parameter.Value \
  --output text > ~/.kube/linguasphere.yaml

export KUBECONFIG=~/.kube/linguasphere.yaml
kubectl get nodes
```

---

## Bước 6 — Triển khai monitoring (Prometheus + Grafana)

```bash
terraform apply -var="deploy_monitoring=true"
```

> Hoặc tạo file `terraform.tfvars` với nội dung `deploy_monitoring = true` để không phải truyền `-var` mỗi lần.

---

## Bước 7 — Truy cập Grafana

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Mở trình duyệt: `http://localhost:3000`

| | |
|---|---|
| Username | `admin` |
| Password | giá trị đã lưu trong Secrets Manager |

---

## Dọn dẹp

```bash
terraform destroy -var="deploy_monitoring=true"
```