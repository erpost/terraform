#!/bin/bash

# Run as Root on Anthos BareMetal Bastion Workstation

# KubeConfig file
cp -p ~/bmctl-workspace/cluster-baremtl1/cluster-baremtl1-kubeconfig ~/.kube/config

# Create Cloud-Console-Reader ClusterRole
cat <<EOF > cloud-console-reader.yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cloud-console-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
EOF
kubectl apply -f cloud-console-reader.yaml

set -x

KSA_NAME=baremtl1-sa
kubectl create serviceaccount ${KSA_NAME}
kubectl create clusterrolebinding baremtl1-clusterrolebinding-view --clusterrole view --serviceaccount default:${KSA_NAME}
kubectl create clusterrolebinding baremtl1-clusterrolebinding-reader --clusterrole cloud-console-reader --serviceaccount default:${KSA_NAME}
kubectl create clusterrolebinding baremtl1-clusterrolebinding-admin --clusterrole cluster-admin --serviceaccount default:${KSA_NAME}

SECRET_NAME=$(kubectl get serviceaccount ${KSA_NAME} -o jsonpath='{$.secrets[0].name}')
kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode
