# kubernetes-setup

Initial configuration for our shared DigitalOcean Kubernetes cluster. For a full deployment example with CI, check out the [example-deployment](https://github.com/public-transport/example-deployment).

[![License](https://img.shields.io/github/license/public-transport/kubernetes-setup.svg?style=flat)](license)

This repository contains scripts to set up a DigitalOcean Kubernetes cluster with

- an [nginx ingress](https://github.com/kubernetes/ingress-nginx) and [cert-manager](https://github.com/jetstack/cert-manager/) - allows you to deploy stuff that can be reached from your own domains, encrypted with certificates issued by [letsencrypt](letsencrypt.org).
- an EFK (elastic search, fluentd, kibana) stack - allows you to access and search logs in a web interface
- a custom name space for your deployments

To setup your own cluster, just [connect to it](https://www.digitalocean.com/docs/kubernetes/how-to/connect-to-cluster/) and run all scripts in [`./initial-setup`](./initial-setup) in the order the files are numbered (start with `1-nginx-ingress.sh`).

## Permissions

This repository also contains a script [`./add-user.sh`](./add-user.sh), which can be used as follows:

```bash
./add-user.sh <some-unique-user-name> <namespace>
```

to generate a key/certificate pair which allows edits on the given namespace. These can then be used e.g. [in your CI](https://github.com/public-transport/example-deployment/blob/668b4bd/.github/workflows/build-push-deploy.yaml#L40).

## Contributing

If you found a bug or want to propose a feature, feel free to visit [the issues page](https://github.com/public-transport/kubernetes-setup/issues).
