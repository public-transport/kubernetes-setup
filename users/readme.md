# Users

Everyone who makes deployments on our shared kubernetes cluster has a specific **namespace** and a corresponding **user** and **service account** which have edit permissions on that namespace. Keep in mind that **everyone can read the logs for every namespace**.

## Obtaining user credentials

If you would like to deploy applications on our shared cluster, get in touch with [Julius](https://github.com/juliuste), who can create a `.kubeconfig` file for you, which can then be used via the `kubectl` command:

```bash
kubectl --kubeconfig .kubeconfig.yaml get services --namespace <your-namespace>
```

Note that you should use a different set of credentials in your CI. Have a look at the section [obtaining CI credentials](#obtaining-ci-credentials) below.

### How to create a kubeconfig (relevant for admins only)

To add a user `some-username` and generate a kubeconfig for them, a person with admin access to the cluster needs to run the script [`./add-user.sh`](./add-user.sh), which can be used as follows:

```bash
./add-user.sh <some-username>
```

This will set up a namespace and service account named `some-username` and `some-username-service-account`, respectively. The resource definitions for all created objects will be placed at `./some-username.yaml` and should be committed to this git repository.

Furthermore, the script also creates a kubeconfig file `./.kubeconfig-some-username.yaml`, which will contain the credentials for the newly created user and should be handed over to them. Note that server information (url, public certificate) for the cluster will be copied from your kubeconfig's *currentContext*, so please point the context to the correct cluster before running the script.

*Note that the generated credentials are valid for one year and need to be re-generated afterwards.*

## Obtaining CI credentials

While you may use your user credentials for deploying from a CI, it is advised to use separate credentials for that, which have a more restricted set of permissions (currently only *get*, *list*, *watch*, *create*, *update* and *patch* for *services*, *deployments* and *ingresses* on your namespace, while your user account has generic edit permissions (including *delete*) for all resource types on that namespace).

To obtain such a set of credentials, get in touch with [Julius](https://github.com/juliuste), who can create a `.kubeconfig` file for you, which can then be used via the `kubectl` command in your ci:

```bash
kubectl --kubeconfig .kubeconfig.yaml get services --namespace <your-namespace>
```

### How to create a CI kubeconfig (relevant for admins only)

Given an existing user `some-username`, you can generate a kubeconfig for their CI using the script [`./add-user.sh`](./add-user.sh), which can be used as follows:

```bash
./add-ci-user.sh <some-username>
```

This will create a new user `some-username-ci` with restricted permissions (check the details in the section above), and appends all new resource definitions to the existing `some-username.yaml` in this directory, which should be committed to the git repository.

Furthermore, the script also creates a kubeconfig file `./.kubeconfig-some-username-ci.yaml`, which will contain the credentials for the newly created CI user. Note that server information (url, public certificate) for the cluster will be copied from your kubeconfig's *currentContext*, so please point the context to the correct cluster before running the script.

*Note that the generated credentials are valid for one year and need to be re-generated afterwards.*
