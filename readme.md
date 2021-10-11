# kubernetes-setup

## :warning: DEPRECATED! This repository is no longer in use, check [public-transport/infrastructure](https://github.com/public-transport/infrastructure) for our latest setup.

Initial configuration for our shared Kubernetes cluster, deployed on Scaleway. For a full deployment example with CI, check out the [example-deployment](https://github.com/public-transport/example-deployment).

**Note that, if you deploy something on our cluster, you commit to the [code of conduct](./code-of-conduct.md).**

[![License](https://img.shields.io/github/license/public-transport/kubernetes-setup.svg?style=flat)](license)

This repository contains scripts to set up a Kubernetes cluster with

- an [nginx ingress](https://github.com/kubernetes/ingress-nginx) and [cert-manager](https://github.com/jetstack/cert-manager/) - allows you to deploy stuff that can be reached from your own domains, encrypted with certificates issued by [letsencrypt](letsencrypt.org)

To setup your own cluster, just connect to it and run all scripts in [`./initial-setup`](./initial-setup) in the order the files are numbered (start with `1-nginx-ingress.sh`).

## Users and permissions

Details on user and permissions management are documented [here](./users/readme.md).

## Logging

**Keep in mind that logs are public for everyone who has access to the cluster, so don't log any sensitive information!**

## Contributing

If you found a bug or want to propose a feature, feel free to visit [the issues page](https://github.com/public-transport/kubernetes-setup/issues).
