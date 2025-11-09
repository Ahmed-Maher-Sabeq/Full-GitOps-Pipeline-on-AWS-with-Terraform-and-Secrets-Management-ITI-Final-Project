#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_name} --kubelet-extra-args '--max-pods=110'
