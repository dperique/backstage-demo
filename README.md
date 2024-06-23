
<p align="center">
  <img src="./logo/backstage-for-home.png" alt="Backstage for Home Logo">
</p>

# Backstage For Home (Or Business)

This is a simple [backstage](backstage.io) deployment with no Guest Authentication running on Openshift (or minikube).
If you want to deploy this on the public Intenet, please secure it (e.g., with a authentication proxy).

Use this as a way to get started with a small and simple, but functional, backstage deployment (just Groups and Users).
Once it's running, you can add more to it.  With just Groups and Users, it is still quite useful.

# Setup on Openshift Local

Get [Openshift Local running](https://www.redhat.com/sysadmin/install-openshift-local).

If you prefer [minikube](https://minikube.sigs.k8s.io/docs/) use the [minikube instructions](./minikube/minikube.md).

NOTE: I included [app-config.production.yaml](./production/app-config.production.yaml) but if you want to use that, you'll have to move it to the root directory of your git clone before running the `podman build` command and ensure the [Dockerfile](./Dockerfile) includes it and references it in the `CMD` command at the bottom using `--config app-config.production.yaml`.

Run these commands to deploy this on Openshift:

```bash
cd openshift
oc login -u developer https://api.crc.testing:6443
oc new-project backstage-for-home

oc delete configmap --ignore-not-found home-backstage-yamls
oc create configmap home-backstage-yamls --from-file=home_org.yaml

oc apply -f buildconfig.yaml
oc apply -f imagestream.yaml
oc apply -f deploymentconfig.yaml
oc apply -f route.yaml
oc apply -f service.yaml
oc start-build backstage-for-home --follow
```

To get credentials from Openshift Local:

```bash
$ crc console --credentials
To login as a regular user, run 'oc login -u developer -p developer https://api.crc.testing:6443'.
To login as an admin, run 'oc login -u kubeadmin -p ... https://api.crc.testing:6443'
```

When creating a project, you get examples:

```bash
$ oc new-project backstage-for-home
Now using project "backstage-for-home" on server "https://api.crc.testing:6443".

You can add applications to this project with the 'new-app' command. For example, try:

    oc new-app rails-postgresql-example

to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:

    kubectl create deployment hello-node --image=registry.k8s.io/e2e-test-images/agnhost:2.43 -- /agnhost serve-hostname
```

Notice this at the bottom of your `/etc/hosts` file:

```bash
# Added by CRC
127.0.0.1        api.crc.testing canary-openshift-ingress-canary.apps-crc.testing console-openshift-console.apps-crc.testing default-route-openshift-image-registry.apps-crc.testing downloads-openshift-console.apps-crc.testing oauth-openshift.apps-crc.testing backstage-for-home-backstage-for-home.apps-crc.testing
# End of CRC section
```

After running the above commands:

```bash
$ oc get route backstage-for-home
NAME          HOST/PORT                                 PATH   SERVICES      PORT       TERMINATION   WILDCARD
backstage-for-home   backstage-for-home-backstage-for-home.apps-crc.testing          backstage-for-home   7007-tcp                 None
```

# Troubleshooting

With Openshfit on my mac, I got segFault on the docker build (using podman):

```bash
yarn run v1.22.22
$ tsc
Done in 5.12s.
yarn run v1.22.22
$ yarn workspace backend build
$ backstage-cli package build
Building app separately because it is a bundled package
app:
app:
app: $ backstage-cli package build
app:
app: Segmentation fault (core dumped)
app:
app:
app: info Visit https://yarnpkg.com/en/docs/cli/run for documentation about this command.
app:
app: error Command failed with exit code 139.
app:
Command 'yarn' exited with code 139
error Command failed with exit code 139.
info Visit https://yarnpkg.com/en/docs/cli/run for documentation about this command.
error Command failed.
Exit code: 139
```

Mitigation: just run openshift local on Fedora.

I'm using these settings on Fedora (with a laptop running with 32G RAM):

```bash
$ crc config view
- consent-telemetry                     : no
- disk-size                             : 100
- memory                                : 16000
- pull-secret-file                      : /home/dperique/Downloads/pull-secret
```

## With the image as written, it does not work

I get this on the log which tells me something is missing:

```
$ oc logs backstage-for-home-4-ktcvr
node:internal/modules/cjs/loader:1143
  throw err;
  ^

Error: Cannot find module '/app/packages/backend'
    at Module._resolveFilename (node:internal/modules/cjs/loader:1140:15)
    at Module._load (node:internal/modules/cjs/loader:981:27)
    at Function.executeUserEntryPoint [as runMain] (node:internal/modules/run_main:128:12)
    at node:internal/main/run_main_module:28:49 {
  code: 'MODULE_NOT_FOUND',
  requireStack: []
}
```

Troubleshoot:

* Outside of Openshift, manually build the image using the Dockerfile, make a container,
  compare it to a "working" pod using `podman run -it --rm --entrypoint /bin/bash <imageName>:latest`

## Login to a node and look around

```bash
$ oc login -u kubeadmin -p ... https://api.crc.testing:6443
Login successful.

$ oc get node
NAME   STATUS   ROLES                         AGE   VERSION
crc    Ready    control-plane,master,worker   28d   v1.28.9+416ecaf

$ oc debug nodes/crc
Temporary namespace openshift-debug-8gjxh is created for debugging node...
Starting pod/crc-debug ...
To use host binaries, run `chroot /host`
Pod IP: 192.168.126.11
If you don't see a command prompt, try pressing enter.

sh-4.4# chroot /host

sh-5.1# podman images|head -5
REPOSITORY                                                                    TAG         IMAGE ID      CREATED        SIZE
image-registry.openshift-image-registry.svc:5000/hello-proj/hello-world       <none>      eb9aced58cba  2 hours ago    937 MB
registry.redhat.io/redhat/community-operator-index                            v4.15       f9d0afafe294  36 hours ago   1.41 GB
<none>                                                                        <none>      878ec13e6baf  44 hours ago   1.41 GB
<none>                                                                        <none>      f435c7462c3f  45 hours ago   1.41 GB
```