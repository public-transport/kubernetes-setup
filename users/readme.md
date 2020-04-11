# Users

Everyone who makes deployments on our shared kubernetes cluster has a specific **namespace** and a corresponding **user** and **service account** which have edit permissions on that namespace. Furthermore, the user also has view permissions on the namespace for our logging infrastracture. Keep in mind that **everyone can read the logs for every namespace**.

If you would like to deploy applications on our shared cluster, get in touch with [Julius](https://github.com/juliuste).

## Adding a user

To add a user `some-username`, a person with admin access to the cluster needs to run the script [`./add-user.sh`](./add-user.sh), which can be used as follows:

```bash
./add-user.sh <some-unique-user-name>
```

This will create a key/certificate pair for a new user with the given name (output to `some-username-credentials.yaml`), that this user can then use in their kubeconfig\*. As stated before, the script also sets up a namespace and service account named `some-username` and `some-username-service-account`, respectively. The resource definitions for these namespaces and service accounts, as well as the corresponding role bindings, can then be found in `some-username.yaml` in this directory.

*\*Note that these credentials are valid for one year and need to be re-generated afterwards.*
