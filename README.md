![Kubent (Kube-No-Trouble) logo](./docs/imgs/kubent-logo.svg)

__*Easily check your clusters for use of deprecated APIs*__

Kubernetes regularly deprecates and removes API versions[1][1], and an upgrade
can break workloads that still use them.

*Kube No Trouble (__`kubent`__)* is a simple tool to check whether you're using
any of these API versions in your cluster and therefore should upgrade your
workloads first, before upgrading your Kubernetes cluster. It covers
Kubernetes releases up to __1.37__.

This tool will be able to detect deprecated APIs depending on how you deploy
your resources, as we need the original manifest to be stored somewhere. In
particular following tools are supported:
- **file**    - local manifests in YAML or JSON
- **kubectl** - uses the `kubectl.kubernetes.io/last-applied-configuration` annotation
- **Helm v3** - uses Helm manifests stored as Secrets or ConfigMaps directly in individual namespaces

[1]: https://kubernetes.io/docs/reference/using-api/deprecation-guide/

**Additional resources:**
- Blog post on K8s deprecated APIs and introduction of kubent: [Kubernetes: Deprecated APIs aka Introducing Kube-No-Trouble][2]

[2]: https://stepan.wtf/kubernetes-deprecated-apis-introducing-kubent/

## Supported Kubernetes versions

`kubent` ships with the following rulesets, embedded in the binary:

| Ruleset | Checks for |
| --- | --- |
| `deprecated-1-16` | APIs removed in 1.16 (e.g. `extensions/v1beta1` Deployments, DaemonSets) |
| `deprecated-1-22` | APIs removed in 1.22 (e.g. `extensions/v1beta1` Ingress, `rbac.authorization.k8s.io/v1beta1`) |
| `deprecated-1-25` | APIs removed in 1.25 (e.g. `batch/v1beta1` CronJob, PodSecurityPolicy) |
| `deprecated-1-26` | APIs removed in 1.26 (e.g. `autoscaling/v2beta2` HorizontalPodAutoscaler) |
| `deprecated-1-27` | APIs removed in 1.27 (`storage.k8s.io/v1beta1` CSIStorageCapacity) |
| `deprecated-1-29` | APIs removed in 1.29 (`flowcontrol.apiserver.k8s.io/v1beta2`) |
| `deprecated-1-32` | APIs removed in 1.32 (`flowcontrol.apiserver.k8s.io/v1beta3`) |
| `deprecated-future` | Deprecated beta APIs that are still served but will be removed in a future release |

Kubernetes 1.33 through 1.37 only removed alpha API versions, which `kubent`
doesn't track, so there is no removal ruleset for those releases. Beta APIs
deprecated in those releases are covered by `deprecated-future`:

| Since | Kinds | Deprecated version(s) → replacement |
| --- | --- | --- |
| 1.21 | VolumeSnapshot, VolumeSnapshotClass, VolumeSnapshotContent | `snapshot.storage.k8s.io/v1beta1` → `v1` |
| 1.28 | SelfSubjectReview | `authentication.k8s.io/v1beta1` → `v1` |
| 1.30 | ValidatingAdmissionPolicy, ValidatingAdmissionPolicyBinding | `admissionregistration.k8s.io/v1beta1` → `v1` |
| 1.33 | IPAddress, ServiceCIDR | `networking.k8s.io/v1beta1` → `v1` |
| 1.34 | VolumeAttributesClass | `storage.k8s.io/v1beta1` → `v1` |
| 1.34 | DeviceClass, ResourceClaim, ResourceClaimTemplate, ResourceSlice | `resource.k8s.io/v1beta1`, `v1beta2` → `v1` |
| 1.36 | MutatingAdmissionPolicy, MutatingAdmissionPolicyBinding | `admissionregistration.k8s.io/v1beta1` → `v1` |
| 1.37 | ClusterTrustBundle, PodCertificateRequest | `certificates.k8s.io/v1beta1` → `v1` |
| 1.37 | StorageVersionMigration | `storagemigration.k8s.io/v1beta1` → `v1` |

*Since* is the release in which the replacement API became available. A
finding is only reported when the target version (see `--target-version`) is
at or above it, so that `kubent` never suggests an API your cluster can't serve
yet.

## Install

Run the following command in your terminal to install `kubent` using a shell script:

```sh
sh -c "$(curl -sSL https://git.io/install-kubent)"
```

*(Unless specified the script will download latest version and unpack to `/usr/local/bin/`).*

> Note: Do not run random scripts from strangers on the internet. Read what the above script does first.

### Manual Installation

You can download the
[latest release](https://github.com/doitintl/kube-no-trouble/releases/latest)
for your cpu architectures and operating system. You can then place it on your path.

We currently maintain, the following operating systems and cpu architectures:

- Linux amd64
- Linux arm64
- Darwin amd64
- Darwin arm64
- Windows amd64

*Historically Windows on arm, has not received the best support. If this changes we may add it.*

Each release also ships native packages, plus a `SHA256SUMS` file to verify downloads:

| Platform | Package | Install |
| --- | --- | --- |
| Debian / Ubuntu (amd64, arm64) | `kubent_<version>_<arch>.deb` | `sudo apt install ./kubent_<version>_<arch>.deb` |
| macOS 13+ (arm64, amd64) | `kubent-<version>-macos-<arch>.pkg` | `sudo installer -pkg kubent-<version>-macos-<arch>.pkg -target /` |
| Windows (amd64) | `kubent-<version>-windows-amd64.zip` | Unzip and put `kubent.exe` on your `PATH` |

The packages aren't signed with a publisher certificate, so macOS Gatekeeper and Windows SmartScreen may warn on
first run. On macOS, a downloaded `.pkg` can be opened with right-click → Open.

### Third-Party Installation

Please note that third-party installation methods are maintained by the community.
**The packages may not always be up-to-date with the latest releases of** `kubent`.

#### Homebrew

`kubent` is available as a [formula](https://formulae.brew.sh/formula/kubent)
on [Homebrew](https://brew.sh/). If you're using macOS or Linux, you can run
the following command to install `kubent`:

```sh
brew install kubent
```

#### Scoop
`kubent` is available for [Scoop](https://scoop.sh/) as an [app](https://bjansen.github.io/scoop-apps/main/kubent/).
Install `kubent` by running:

```powershell
scoop install kubent
```

## Usage

Configure Kubectl's current context to point to your cluster, `kubent` will
look for the kube `.config` file in standard locations (you can point it to custom
location using the `-k` switch).

**`kubent`** will collect resources from your cluster and report on found issues.

*Please note that you need to have sufficient permissions to read Secrets in the
cluster in order to use `Helm*` collectors.*

For example, checking a few of the test manifests from [fixtures/](fixtures/)
against Kubernetes 1.37:

```sh
$ kubent -c=false --helm3=false -t 1.37 \
    -f fixtures/ingress-v1beta1.yaml -f fixtures/flowschema-v1beta3.yaml \
    -f fixtures/validatingadmissionpolicy-v1beta1.yaml -f fixtures/resourceclaim-v1beta1.yaml
3:20PM INF >>> Kube No Trouble `kubent` <<<
3:20PM INF version 0.8.0-dev (git sha 3bff8d1)
3:20PM INF Initializing collectors and retrieving data
3:20PM INF Target K8s version is 1.37.0
3:20PM INF Retrieved 4 resources from collector name=File
3:20PM INF Loaded ruleset name=custom.rego.tmpl
3:20PM INF Loaded ruleset name=deprecated-1-16.rego
3:20PM INF Loaded ruleset name=deprecated-1-22.rego
3:20PM INF Loaded ruleset name=deprecated-1-25.rego
3:20PM INF Loaded ruleset name=deprecated-1-26.rego
3:20PM INF Loaded ruleset name=deprecated-1-27.rego
3:20PM INF Loaded ruleset name=deprecated-1-29.rego
3:20PM INF Loaded ruleset name=deprecated-1-32.rego
3:20PM INF Loaded ruleset name=deprecated-future.rego
__________________________________________________________________________________________
>>> Deprecated APIs removed in 1.22 <<<
------------------------------------------------------------------------------------------
KIND      NAMESPACE     NAME           API_VERSION          REPLACE_WITH            (SINCE)
Ingress   <undefined>   test-ingress   extensions/v1beta1   networking.k8s.io/v1    (1.19.0)
__________________________________________________________________________________________
>>> Deprecated APIs removed in 1.32 <<<
------------------------------------------------------------------------------------------
KIND         NAMESPACE     NAME                    API_VERSION                            REPLACE_WITH                       (SINCE)
FlowSchema   <undefined>   service-accounts-test   flowcontrol.apiserver.k8s.io/v1beta3   flowcontrol.apiserver.k8s.io/v1    (1.29.0)
__________________________________________________________________________________________
>>> Deprecated APIs to be removed in future <<<
------------------------------------------------------------------------------------------
KIND                        NAMESPACE     NAME                      API_VERSION                            REPLACE_WITH                       (SINCE)
ResourceClaim               default       single-gpu                resource.k8s.io/v1beta1                resource.k8s.io/v1                 (1.34.0)
ValidatingAdmissionPolicy   <undefined>   demo-policy.example.com   admissionregistration.k8s.io/v1beta1   admissionregistration.k8s.io/v1    (1.30.0)
```

If no tables are printed after the `Loaded ruleset` lines, no deprecated APIs
were found.

### Arguments

You can list all the configuration options available using `--help` switch:
```sh
$./kubent -h
Usage of ./kubent:
  -A, --additional-annotation strings   additional annotations that should be checked to determine the last applied config
  -a, --additional-kind strings         additional kinds of resources to report in Kind.version.group.com format
  -c, --cluster                         enable Cluster collector (default true)
  -x, --context string                  kubeconfig context
  -e, --exit-error                      exit with non-zero code when issues are found
  -f, --filename strings                manifests to check, use - for stdin
      --helm3                           enable Helm v3 collector (default true)
  -k, --kubeconfig string               path to the kubeconfig file
      --labels                          print resource labels
  -l, --log-level string                set log level (trace, debug, info, warn, error, fatal, panic, disabled) (default "info")
  -o, --output OutputFormat             output format - [text|json|csv] (default text)
  -O, --output-file string              output file, use - for stdout (default "-")
  -t, --target-version string           target K8s version in SemVer format (autodetected by default)
  -v, --version                         prints the version of kubent and exits
```
- *`--additional-annotation`*
  Check additional annotations for the last applied configuration. This can be useful if a resource was applied
  with a tool other than kubectl. The flag can be used multiple times.

- *`-a, --additional-kind`*
  Tells `kubent` to flag additional custom resources when found in the specified version. The flag can be used multiple
  times. The expected format is full *Kind.version.group.com* form - e.g. `-a ManagedCertificate.v1.networking.gke.io`.

- *`-x, --context`*
  Select context from kubeconfig file (`current-context` from the file is used by default).

- *`-k, --kubeconfig`*
  Path to kubeconfig file to use. This takes precedence over `KUBECONFIG` environment variable, which is also supported
  and can contain multiple paths, and default `~/.kube/config`.

- *`-t, --target-version`*
  `kubent` will try to detect K8S cluster version and display only relevant findings. This flag allows to override this
  version for scenarios like use in CI with the file collector only, when detection from an actual cluster is not possible.
  Expected format is `major.minor[.patch]`, e.g. `1.16` or `1.16.3`.
  It's also how you check readiness for an upgrade: `kubent -t 1.37` against a 1.32 cluster reports everything that
  would need to change before moving to 1.37.

### Docker Image

We also publish official container image, which can be found at:
`ghcr.io/doitintl/kube-no-trouble:latest` (also available tagged with each
individual release version).

To run locally, you'll need to provide credentials, e.g. by sharing your
kubectl config:

```sh
$ docker run -it --rm \
    -v "${HOME}/.kube/config:/.kubeconfig" \
    ghcr.io/doitintl/kube-no-trouble:latest \
    -k /.kubeconfig
```

You can use `kubectl run` to run inside a K8S cluster, as a one-off. In that
case the credentials will be picked up via the pod's service account from the
environment, but you'll want to grant relevant permissions first (see
[docs/k8s-sa-and-role-example.yaml](docs/k8s-sa-and-role-example.yaml)):

```sh
$ kubectl run kubent --restart=Never --rm -i --tty \
    --image ghcr.io/doitintl/kube-no-trouble:latest \
    --overrides='{"spec": {"serviceAccount": "kubent"}}'
```

### Use in CI

#### Exit codes

`kubent` will by default return `0` exit code if the program succeeds, even if
it finds deprecated resources, and non-zero exit code if there is an error
during runtime. Because all info output goes to stderr, it's easy to check in
shell if any issues were found:

```shell
test -z "$(kubent)"                 # if stdout output is empty, means no issues were found
                                    # equivalent to [ -z "$(kubent)" ]
```

It's actually better so split this into two steps, in order to differentiate
between runtime error and found issues:

```shell
if ! OUTPUT="$(kubent)"; then       # check for non-zero return code first
  echo "kubent failed to run!"
elif [ -n "${OUTPUT}" ]; then       # check for empty stdout
  echo "Deprecated resources found"
fi
```

You can also use `--exit-error` (`-e`) flag, which will make kubent to exit
with non-zero return code (`200`) in case any issues are found.

Alternatively, use the json output and smth. like `jq` to check if the result is
empty:

```
kubent -o json | jq -e 'length == 0'
```

#### Scanning all files in directory

If you want to scan all files in a given directory, you can use the following
shell snippet:

```shell
FILES=($(ls *.yaml)); kubent ${FILES[@]/#/-f} --helm3=false -c=false
```

## Development

Building `kubent` requires Go 1.26 or newer. The simplest way to build it is:

```sh
# Clone the repository
git clone https://github.com/doitintl/kube-no-trouble.git
cd kube-no-trouble/
# Build
go build -o bin/kubent ./...
```

Otherwise there's `Makefile`
```sh
$ make
make
all                            Clean, build and pack
build                          Build binary
changelog                      Generate Changelog based on PRs
clean                          Clean build artifacts
help                           Prints list of tasks
release-artifacts              Create release artifacts
test                           Run Go tests
test-fmt                       Run go and opt fmt checks
```

Rules live in [pkg/rules/rego/](pkg/rules/rego/), with a test manifest for each
deprecated API in [fixtures/](fixtures/) and the matching test cases in
[test/](test/). Run them with `go test ./...`.

## Issues and Contributions

Please open any issues and/or PRs against github.com/doitintl/kube-no-trouble repository. See our [contribution guide](.github/CONTRIBUTING.md) for more details
