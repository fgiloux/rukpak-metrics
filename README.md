# RukPak Metrics

## Content

This repository contains the script and recording of a short demo of [RukPak](github.com/operator-framework/rukpak/) metrics.
RukPak is a component of OLMv1 in charge of applying content to a Kubernetes cluster.

## Demo

 Recording of it (4:26 min)

[![asciicast](https://asciinema.org/a/613251.svg)](https://asciinema.org/a/613251)

## Setup

1. Cert-manager installation

~~~
$ kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
~~~

2. RukPak installation

~~~
$ kubectl apply -f https://github.com/operator-framework/rukpak/releases/latest/download/rukpak.yaml
~~~

3. Label the core service
The ServiceMonitor can leverage the label for selecting the endpoints to monitor

~~~
$ kubectl label svc core -n rukpak-system app=rukpak-core
~~~

4. Create a serviceaccount and its token secret used for scrapping the metrics

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
  name: prometheus
  namespace: rukpak-system
EOF
~~~

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-token
  annotations:
    kubernetes.io/service-account.name: "prometheus" 
type: kubernetes.io/service-account-token
EOF
~~~

5. Provide access rights to the Prometheus serviceaccount

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: clusterrole
    app.kubernetes.io/instance: metrics-reader
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: rukpak
    app.kubernetes.io/part-of: rukpak
  name: metrics-reader
rules:
- nonResourceURLs:
  - "/metrics"
  verbs:
  - get
EOF
~~~

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metrics-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metrics-reader
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: rukpak-system
EOF
~~~

6. Create a ServiceMonitor for RukPak core

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: rukpak-core
  name: rukpak-core
  namespace: rukpak-system
spec:
  endpoints:
    - path: /metrics
      port: https
      scheme: https
      bearerTokenSecret:
        name: prometheus-token
        key: token
      tlsConfig:
        ca:
          secret:
            name: core-cert
            key: ca.crt
        serverName: core.rukpak-system.svc.cluster.local
  selector:
    matchLabels:
      app: rukpak-core
EOF
~~~


7. Configuring user workload monitoring (OpenShift specific)

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
EOF
Add enableUserWorkload: true under data/config.yaml:
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
~~~

Alternatively [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) can be installed.

8. Grafana installation (OpenShift specific)

Grafana is part of the components of kube-prometheus. An alternative with OpenShift is to query from a central place the metrics exposed through the Thanos Querier.

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  creationTimestamp: "2023-10-10T12:21:21Z"
  generation: 1
  labels:
    operators.coreos.com/grafana-operator.openshift-operators: ""
  name: grafana-operator
  namespace: openshift-operators
  resourceVersion: "1551710"
  uid: eb81dad0-ef1a-42dc-b643-dbf9a4bf284c
spec:
  channel: v5
  installPlanApproval: Automatic
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: grafana-operator.v5.4.1
EOF
~~~

Creation of a Grafana instance.

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  labels:
    dashboards: grafana-a
    folders: grafana-a
  name: grafana-a
  namespace: openshift-operators
spec:
  config:
    auth:
      disable_login_form: 'false'
    log:
      mode: console
    security:
      admin_password: <start>
      admin_user: <root>
~~~

Take note of the credentials you configured.

Give rights to scrap metrics from Prometheus to the Grafana service account.

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-monitoring-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-monitoring-view
subjects:
- kind: ServiceAccount
  name: grafana-a-sa
EOF
~~~

Get the token of the grafana-a-sa service account and provide it in a GrafanaDatasource.

~~~
$ cat <<EOF | kubectl apply -f -
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: grafanadatasource
  namespace: openshift-operators
spec:
  datasource:
    access: proxy
    editable: true
    isDefault: true
    jsonData:
      httpHeaderName1: Authorization
      timeInterval: 5s
      tlsSkipVerify: true
    name: prometheus
    secureJsonData:
      httpHeaderValue1: >-
        Bearer ${BEARER_TOKEN}
    type: prometheus
    url: >-
      https://thanos-querier.openshift-monitoring.svc.cluster.local:9091
  instanceSelector:
    matchLabels:
      dashboards: grafana-a
  plugins:
    - name: grafana-clock-panel
      version: 1.3.0
~~~

Create an ingress/route for the service

~~~
$ oc expose service grafana-a-service
~~~

Log into Grafana using the credentials previously noted.

## References

[Kubebuilder metrics reference](https://book.kubebuilder.io/reference/metrics-reference)

[Prometheus Go client library](https://github.com/prometheus/client_golang)

