# EBS CSI Driver - Automated Installation

## Overview

The EBS CSI (Container Storage Interface) driver is now automatically installed by Terraform. This is **critical** for Jenkins persistent storage to work.

## What It Does

The EBS CSI driver allows Kubernetes to:
- ✅ Dynamically provision EBS volumes
- ✅ Attach volumes to pods
- ✅ Manage volume lifecycle
- ✅ Support persistent volume claims (PVCs)

Without it, Jenkins PVC would be stuck in "Pending" state.

## What Terraform Deploys

### 1. IAM Policy
Creates policy with permissions for:
- Creating/deleting EBS volumes
- Creating/deleting snapshots
- Attaching/detaching volumes
- Describing volumes and instances
- Managing tags

### 2. IAM Role
Creates role with:
- Trust policy for EKS OIDC provider
- Assumable by `system:serviceaccount:kube-system:ebs-csi-controller-sa`
- Attached EBS CSI policy

### 3. EKS Addon
Installs EBS CSI driver as EKS addon:
- Version: v1.25.0-eksbuild.1
- Service account: `ebs-csi-controller-sa` in `kube-system`
- IRSA configured automatically

## Verification

After `terraform apply`, verify installation:

```bash
# Check addon status
aws eks describe-addon \
  --cluster-name gitops-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1

# Check CSI driver pods
kubectl get pods -n kube-system | grep ebs-csi

# Expected output:
# ebs-csi-controller-xxx   6/6     Running
# ebs-csi-node-xxx         3/3     Running

# Check CSI driver
kubectl get csidriver

# Expected output:
# NAME              ATTACHREQUIRED   PODINFOONMOUNT   STORAGECAPACITY
# ebs.csi.aws.com   true             false            false

# Check storage class
kubectl get storageclass

# Expected output:
# NAME            PROVISIONER             RECLAIMPOLICY
# gp2 (default)   kubernetes.io/aws-ebs   Delete
```

## How Jenkins Uses It

When Jenkins is deployed:

1. Jenkins Helm chart creates a PVC:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 10Gi
```

2. EBS CSI driver sees the PVC

3. Driver creates an EBS volume (10GB gp2)

4. Driver attaches volume to Jenkins pod

5. Jenkins data persists across pod restarts

## Troubleshooting

### Issue: PVC stuck in Pending

**Check CSI driver pods:**
```bash
kubectl get pods -n kube-system | grep ebs-csi
```

**Check PVC events:**
```bash
kubectl describe pvc jenkins -n jenkins
```

**Check CSI driver logs:**
```bash
kubectl logs -n kube-system -l app=ebs-csi-controller
```

### Issue: CSI driver pods not running

**Check IAM role:**
```bash
aws iam get-role --role-name aws-gitops-pipeline-dev-ebs-csi-driver-role
```

**Check service account:**
```bash
kubectl get sa ebs-csi-controller-sa -n kube-system -o yaml
```

Should have annotation:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::287043460305:role/aws-gitops-pipeline-dev-ebs-csi-driver-role
```

### Issue: Volume creation fails

**Check IAM permissions:**
```bash
aws iam get-policy-version \
  --policy-arn $(aws iam list-policies --query 'Policies[?PolicyName==`aws-gitops-pipeline-dev-ebs-csi-driver-policy`].Arn' --output text) \
  --version-id v1
```

**Check node IAM role:**
```bash
aws iam list-attached-role-policies \
  --role-name aws-gitops-pipeline-dev-eks-node-group-role
```

## Benefits

✅ **Automatic** - No manual installation needed
✅ **Secure** - Uses IRSA, no credentials in pods
✅ **Managed** - EKS addon auto-updates
✅ **Reliable** - AWS-managed driver
✅ **Integrated** - Works seamlessly with EKS

## Cost

EBS volumes created by the CSI driver:
- **Type**: gp2 (General Purpose SSD)
- **Size**: 10GB (for Jenkins)
- **Cost**: ~$1/month per volume
- **Lifecycle**: Deleted when PVC is deleted

## Important Notes

1. **Addon Version**: Using v1.25.0-eksbuild.1 (compatible with EKS 1.28)
2. **Service Account**: Created automatically by addon
3. **IRSA**: Configured automatically by Terraform
4. **Storage Class**: Uses default `gp2` storage class
5. **Reclaim Policy**: Delete (volume deleted when PVC deleted)

## Terraform Resources

```hcl
# IAM Policy
aws_iam_policy.ebs_csi_driver

# IAM Role
aws_iam_role.ebs_csi_driver

# Policy Attachment
aws_iam_role_policy_attachment.ebs_csi_driver

# EKS Addon
aws_eks_addon.ebs_csi_driver
```

## Outputs

Terraform provides these outputs:

```bash
terraform output ebs_csi_driver_role_arn
# arn:aws:iam::287043460305:role/aws-gitops-pipeline-dev-ebs-csi-driver-role

terraform output ebs_csi_driver_installed
# v1.25.0-eksbuild.1
```

## Summary

The EBS CSI driver is now fully automated:
- ✅ IAM policy created
- ✅ IAM role created with IRSA
- ✅ EKS addon installed
- ✅ Ready for persistent volumes
- ✅ Jenkins storage will work automatically

No manual steps required!
