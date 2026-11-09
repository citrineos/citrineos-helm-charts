# citrineos-helm

Helm charts for running [CitrineOS](https://github.com/citrineos) on Kubernetes. Each chart is
published to the GitHub Container Registry as an OCI artifact under an immutable version.

## Charts

| Folder | Chart name | Published to | Default image |
|---|---|---|---|
| `charts/citrineos-ocpp` | `citrineos-ocpp` | `oci://ghcr.io/citrineos/charts/citrineos-ocpp` | `ghcr.io/citrineos/citrineos-server` |
| `charts/citrineos-ocpi` | `citrineos-ocpi` | `oci://ghcr.io/citrineos/charts/citrineos-ocpi` | `ghcr.io/citrineos/citrineos-ocpi` |
| `charts/citrineos-operator-ui` | `citrineos-operator-ui` | `oci://ghcr.io/citrineos/charts/citrineos-operator-ui` | `ghcr.io/citrineos/citrineos-operator-ui` |

`citrineos-ocpp` deploys the OCPP server from
[citrineos-core](https://github.com/citrineos/citrineos-core) (`apps/ocpp-server`), whose image is
published as `citrineos-server`.

## Installing a chart

```sh
helm install citrineos-ocpp oci://ghcr.io/citrineos/charts/citrineos-ocpp --version 0.12.0 -f my-values.yaml
```

The image a release runs is set by `image.tag` (`global.image.tag` in `citrineos-ocpp`).
`appVersion` in `Chart.yaml` is informational.

### From Flux

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: citrineos
  namespace: flux-system
spec:
  type: oci
  url: oci://ghcr.io/citrineos/charts
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: citrineos-ocpi
spec:
  chart:
    spec:
      chart: citrineos-ocpi
      version: "0.4.0"
      sourceRef:
        kind: HelmRepository
        name: citrineos
        namespace: flux-system
  values: {}
```

To roll back, set `version:` back to the previous one.

## Changing a chart

1. Branch from `main` and edit the chart.
2. Bump `version:` in its `Chart.yaml`: patch for a fix, minor for a new option, major if
   existing releases must change their values. A changed chart without a bump fails the PR check,
   and a version can never be published twice.
3. Check it locally:
   ```sh
   helm repo add haproxytech https://haproxytech.github.io/helm-charts --force-update  # citrineos-ocpp's dependency
   helm dependency build charts/<chart>
   helm lint charts/<chart>
   helm template test charts/<chart> > /dev/null
   scripts/check-version-bump.sh origin/main
   ```
4. Open a PR. The `lint` workflow lints and renders every chart and checks version bumps.
5. Merge, then publish it (below).

## Publishing a chart

Publishing is triggered by pushing a tag named `<chart>-<version>`, where `<chart>` is the folder
under `charts/` and `<version>` is the `version:` in its `Chart.yaml`:

```sh
git checkout main && git pull
git tag citrineos-ocpp-0.12.0
git push origin citrineos-ocpp-0.12.0
```

The `release` workflow then packages `charts/<chart>` and pushes it to
`oci://ghcr.io/<owner>/charts/<chart>:<version>` using the workflow's `GITHUB_TOKEN`. It fails
without publishing if the tag's version doesn't match `Chart.yaml`, or if that version is already
in the registry.

A new package on ghcr.io starts out private. After a chart's first publish, an org admin must set
its visibility to public in the package settings.

## Rules

- **No credentials in chart defaults.** A published chart can be downloaded by anyone, and a
  published version can't be replaced. Secret env vars come from a Kubernetes Secret through
  `envFromSecretKeys` (`global.sharedEnvFromSecretKeys` in `citrineos-ocpp`), set in each
  release's values.
- **No environment-specific defaults where avoidable.** Endpoints and client IDs belong in the
  release's values.
- **New features default to off,** so adopting a new version doesn't change a release's behaviour
  unless its values opt in. The exception is `citrineos-ocpp`'s PodDisruptionBudget for `router`.
- **Publishing is CI-only, from a tag.** No registry credentials are stored in this repo.

## Pod scheduling

Every chart takes `nodeSelector`, `affinity`, `tolerations` and `topologySpreadConstraints` from
its values and passes them straight to the pod spec. Changing where something runs does not need
a chart change.

For the single-deployment charts, `citrineos-ocpi` and `citrineos-operator-ui`, set them at the
top level of `values`:

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - { key: example.com/pool, operator: In, values: [app] }
```

`citrineos-ocpp` renders one workload per entry under `deployments`, so each one can be
scheduled separately. Any of the four keys may be set **per deployment**, and each falls back
to the top-level value on its own when the deployment does not set it:

```yaml
# applies to every deployment that does not override it
tolerations:
  - { key: example.com/pool, operator: Equal, value: app, effect: NoSchedule }

deployments:
  router:
    # router alone pins to its own pool; still inherits the toleration above
    nodeSelector:
      example.com/pool: router
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        matchLabelKeys: [rollouts-pod-template-hash]
        labelSelector:
          matchLabels: { app: citrineos-ocpp, component: router }
  modules:
    nodeSelector:
      example.com/pool: modules
```
