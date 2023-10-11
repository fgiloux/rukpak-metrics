#!/usr/bin/env bash

set -o errexit

export DEMO_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source ${DEMO_DIR}/demo-magic
source ${DEMO_DIR}/helper.sh

export TERM=xterm-256color

cols=100
if command -v tput &> /dev/null; then
  output=$(echo -e cols | tput -S)
  if [[ -n "${output}" ]]; then
    cols=$((output - 10))
  fi
fi
export cols

TYPE_SPEED=30
DEMO_PROMPT="rukpak-metrics-demo $ "
DEMO_COMMENT_COLOR=$GREEN

c "Hi, this is a short demo of the metrics exposed by RukPak"
c "Currently, this is what you get out of the box when using controller-runtime.\n"

c "RukPak has been installed"
pe "kubectl get pods -n rukpak-system"

c "Cert-manager is used for generating and rotating certificates that are used to secure the metrics endpoint."
pe "kubectl api-resources | grep cert-manager"

c "The authorization on the metrics endpoint is ensured by kube-rbac-proxy."
pe "kubectl get deployment core -n rukpak-system -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"

c "kube-rbac-proxy is configured with path based authorization."
c "it is leveraging standard Kubernetes RBAC for access management."
pe "kubectl get clusterrole metrics-reader -o yaml"

c "On the client side we have a serviceaccount, which is used by Prometheus to scrape metrics."
pe "kubectl get sa prometheus -n rukpak-system"
c "And credentials have been generated for it"
pe "kubectl get secrets prometheus-token -n rukpak-system"

c "A serviceMonitor informs Prometheus of metrics endpoints and access parameters."
pe "kubectl get servicemonitor rukpak-core -n rukpak-system -o yaml"

c "For the purpose of the demo a route (similar to ingress) has been created to query the metrics."
pe "kubectl get routes -n rukpak-system"

c "The token from the Prometheus secret has been exported into the token environment variable."
c "We can now check the metrics exposed by RukPak."
c "They include information on the workqueue, e.g. depth and duration (buckets):"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep workqueue_depth"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep workqueue_queue_duration"
c "Reconciliation total, errors and duration (buckets):"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep reconcile_total"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep reconcile_errors"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep reconcile_time"
c "We also have metrics on memory, garbage collection and scheduling:"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep go_memstats"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep go_gc"
pe "curl -X GET -kG -H \"Authorization: Bearer \$token\" https://core-rukpak-system.apps.shrocp4upi413ovn.lab.upshift.rdu2.redhat.com/metrics | grep go_threads"

c "controller-runtime metrics are listed here: https://book.kubebuilder.io/reference/metrics-reference"
c "Prometheus golang client provides the default metrics on memory, garbage collection and scheduling: https://github.com/prometheus/client_golang"
c "That's it, thank you for watching!"

