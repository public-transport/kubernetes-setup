# kubernetes-setup

Initial configuration for our shared Kubernetes cluster, deployed on Scaleway. For a full deployment example with CI, check out the [example-deployment](https://github.com/public-transport/example-deployment).

[![License](https://img.shields.io/github/license/public-transport/kubernetes-setup.svg?style=flat)](license)

This repository contains scripts to set up a Kubernetes cluster with

- an [nginx ingress](https://github.com/kubernetes/ingress-nginx) and [cert-manager](https://github.com/jetstack/cert-manager/) - allows you to deploy stuff that can be reached from your own domains, encrypted with certificates issued by [letsencrypt](letsencrypt.org).
- an EFK (elastic search, fluentd, kibana) stack - allows you to access and search logs in a web interface

To setup your own cluster, just [connect to it](https://www.digitalocean.com/docs/kubernetes/how-to/connect-to-cluster/) and run all scripts in [`./initial-setup`](./initial-setup) in the order the files are numbered (start with `1-nginx-ingress.sh`).

## Users and permissions

Details on user and permissions management are documented [here](./users/readme.md).

## Contributing

If you found a bug or want to propose a feature, feel free to visit [the issues page](https://github.com/public-transport/kubernetes-setup/issues).
