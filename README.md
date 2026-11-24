# FirmwareCI Action

Test firmware with [FirmwareCI](https://firmware-ci.com) from GitHub Actions or
[Forgejo Actions](#forgejo-actions). The action runs a workflow's tests on FirmwareCI, on a board in its lab, or
with `local: true` on the runner itself, next to your board. Both go through `fwci run`, which the action
installs, and take the same inputs. GitLab CI gets the same through a [template](#gitlab-ci).

```yaml
- uses: actions/checkout@v7
- run: make build
- uses: BlindspotSoftware/actions@v8
  with:
    workflow: crystal-core
    binaries: Binary=build/coreboot.rom
    token: ${{ secrets.FWCI_TOKEN }}
```

| You want | Add |
| --- | --- |
| Some tests, not all | `tests: boot, flash`, by the names in their files |
| The run on this runner, not FirmwareCI | `local: true` |
| A particular DUT for a run on this runner | `dut: board-2`; without it, the first free DUT with the workflow's label |
| This checkout's tests on FirmwareCI, not the synced ones | `synced: false` |
| The step to wait for the results on FirmwareCI | `follow: true` |

## On FirmwareCI

FirmwareCI finds the workflow in this repository's project, on the branch the run is on, and runs each test as a
job on any free DUT with the workflow's label. In CI the checkout is the pushed commit, so the action runs the
tests as FirmwareCI synced them from it, which is what lets FirmwareCI report on the commit; `fwci run` at your
desk runs your checkout's tests on your machine, or with `--remote` on FirmwareCI. The step ends once the request
is sent, and the FirmwareCI app reports the results on the commit. With `synced: false` nothing reports them, and
they show only on FirmwareCI.
With `follow: true` the step waits for the jobs instead: it fails on a failed test, the job's own check gets an
annotation for each failed step, the run's summary page a table of the tests, and `fwci.log` and `report.xml`
are kept as an artifact. The runner is held while the jobs queue.

Each job and matrix leg keeps its own artifact. When the action runs twice in one job, or to choose the name,
set `artifact`, such as `artifact: fwci-${{ matrix.board }}`.

FirmwareCI picks the DUT, so `dut` is refused there: give a board a label of its own to run on it alone.

On `pull_request` events, leave `commit_hash` unset: the action reports on the PR head. `${{ github.sha }}` is
GitHub's merge commit, not the commit under test.

## On This Runner

With `local: true` the tests come from this checkout's `.firmwareci` and run one after another on one DUT, with
no FirmwareCI login. Without `dut`, that's the first free DUT with the workflow's label. The runner needs Docker
and has to reach the board: a GitHub-hosted runner reaches only `virtual` and `mock` DUTs, so a board needs a
self-hosted runner next to it. Results show as with `follow`, and the artifact is kept also when a test fails. A
test's `[[secrets.X]]` comes from `FWCI_SECRET_X` in the step's `env`.

In a public repository, a pull request from a fork brings its own `.firmwareci`, and its tests would run on your
board with the runner's Docker. Run such a job only on `push`, or require approval for workflows from outside
contributors. Artifacts of a public repository are public too, so `fwci.log` holds nothing a stranger shouldn't
read.

The step's exit code says how it went: 0 every test passed, 7 a test failed, 1 a test didn't finish, such as a
job aborted on FirmwareCI, or another error, 6 a test couldn't start, 10 every DUT is held by someone else or its
agent can't be reached, which may be a wrong `Agent` in its `dut.yaml`. With `follow: true` and
`args: --follow=2h` the step waits for the jobs at most that long and then exits 8, with the tests still running
skipped in `report.xml`.
`wait` waits only for held DUTs.

## Inputs

| Input | Description |
| --- | --- |
| `workflow` | The workflow to run, by name. Required. |
| `tests` | Test names, separated by commas or newlines. Default: all of the workflow's |
| `binaries` | `name=file`, or `name=URL` on FirmwareCI, separated by `;` or newlines, for `[[input.name]]`. |
| `local` | `true` runs the tests on this runner instead of FirmwareCI. Default: `false` |
| `synced` | On FirmwareCI, the tests as FirmwareCI synced them, reported on the commit. `false` sends this checkout's tests, as a one-shot run not reported on a commit. Default: `true` |
| `args` | More arguments for `fwci run`, such as `--verbose`. |
| `working_directory` | Where fwci runs, and binaries are relative to. With `local: true` or `synced: false`, inside the repository whose `.firmwareci` holds the workflow. Default: `.` |
| `artifact` | Name of the artifact with `fwci.log` and `report.xml`, with `local: true` or `follow`. Empty keeps none. Default: `fwci-<job>-<matrix index>` |
| `version` | The fwci to install, `0.21.0` or newer. `installed` uses the one on the `PATH`. Default: `latest` |
| **On FirmwareCI** | |
| `token` | A FirmwareCI organization or user API token. |
| `email`, `password` | Log in with these instead of a token. |
| `organization` | The organization to submit to, when the credential reaches more than one. An organization token names its own. |
| `follow` | `true` waits for the jobs, see above. Default: `false` |
| `priority` | `low`, `mid` or `high`. Unset, FirmwareCI queues the run at `mid`, or at `high` with `synced: false`. |
| `branch` | The branch to find the workflow on. Defaults to the branch the run is on. |
| `project_link` | The repository holding the FirmwareCI config, when it isn't this one: `org/repo` on GitHub, else `host/org/repo` or a URL, such as `gitlab.com/org/repo`. Needs `synced` (the default). |
| `commit_hash` | The commit to report on. Defaults to the PR head, or the commit the run is on. Needs `synced` (the default). |
| `action` | A label for the run, such as `nightly` or `release`. Needs `synced` (the default). |
| `github_installation_id` | The FirmwareCI GitHub App's installation, when `project_link` is in another GitHub organization. Needs `synced` (the default). |
| `api` | The FirmwareCI API. Default: `https://api.firmware-ci.com` |
| **On this runner** | |
| `dut` | The DUT, by its directory under `.firmwareci/duts` or its `name`. It must carry the workflow's label. |
| `wait` | `true` waits while someone else holds the DUTs, `30m` at most that long. |
| `storage` | `name=directory`, separated by `;` or newlines, for `[[storage.name]]`. |
| `ssh_keys` | `name=private key file`, separated by `;` or newlines, for `[[ssh-keys.name]]`. |

## Authentication

Add a FirmwareCI API token as the secret `FWCI_TOKEN` (Settings, Secrets and variables, Actions) and pass it as
`token`. Create one under **Tokens** in your FirmwareCI profile, or an organization token under **Org
settings**. `email` and `password` work too. A run on this runner needs none.

## GitLab CI

[`templates/fwci.gitlab-ci.yml`](templates/fwci.gitlab-ci.yml) has a job to extend, with the same switches as
variables. It runs the `firmwareci/action:v8` image, which follows the newest fwci within a day;
`firmwareci/action:0.21.0` and so on keep one:

```yaml
include:
  - remote: https://raw.githubusercontent.com/BlindspotSoftware/actions/v8/templates/fwci.gitlab-ci.yml

firmware-test:
  extends: .fwci
  variables:
    FWCI_WORKFLOW: crystal-core
    FWCI_BINARIES: Binary=build/coreboot.rom
```

`FWCI_TESTS`, `FWCI_BINARIES`, `FWCI_LOCAL`, `FWCI_SYNCED`, `FWCI_DUT` and `FWCI_FOLLOW` work as the inputs
above, and `FWCI_ARGS` takes more `fwci run` flags, such as `--priority low`. Set `FWCI_TOKEN` as a masked CI/CD
variable, and `FWCI_ORG` when the token reaches more than one organization. `FWCI_GITLAB_TOKEN` is needed only
if the project's GitLab integration has no token: a project access token with `api` scope, for FirmwareCI to
report back. When the job waits for the tests, GitLab shows `report.xml` in the merge request.

A run on the runner with a docker executor needs the host's network and Docker socket, and a cache directory at the same
path in the job as on the host, as fwci hands paths in it to the host's Docker. In the runner's `config.toml`:

```toml
[[runners]]
  executor = "docker"
  environment = ["XDG_CACHE_HOME=/var/cache/fwci"]
  [runners.docker]
    network_mode = "host"
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/var/cache/fwci:/var/cache/fwci"]
```

## Forgejo Actions

Forgejo looks up a `uses:` name in its own mirror of actions, so name this one by its URL:

```yaml
- uses: actions/checkout@v4
- run: make build
- uses: https://github.com/BlindspotSoftware/actions@v8
  with:
    workflow: crystal-core
    binaries: Binary=build/coreboot.rom
    token: ${{ secrets.FWCI_TOKEN }}
```

Add the token as the secret `FWCI_TOKEN` under the repository's Settings, Actions, Secrets. To link the repository
to FirmwareCI, see [Forgejo Integration](https://docs.firmware-ci.com/usage/2_repository_setup/2_integration_forgejo/).

The action keeps no artifact on Forgejo, as `actions/upload-artifact` v4 and newer refuse any server but
GitHub's. To keep `fwci.log` and `report.xml`, add Forgejo's fork after the action:

```yaml
- uses: https://code.forgejo.org/forgejo/upload-artifact@v5
  if: always()
  with:
    name: fwci
    path: |
      fwci.log
      report.xml
```

## v7 and Older

`docker://firmwareci/action:v7.0` keeps working as before, with its upper-case inputs, and gets no more changes.
To move to v8, use `BlindspotSoftware/actions@v8` in GitHub Actions; the v8 image fails a `docker://` step. In
GitLab CI, extend `.fwci` instead of running `/bin/action` in the v7.0 image.

| v7 | v8 input | v8 GitLab variable |
| --- | --- | --- |
| `WORKFLOW_NAME` | `workflow` | `FWCI_WORKFLOW` |
| `INDIVIDUAL_TESTS` | `tests` | `FWCI_TESTS` |
| `BINARIES` | `binaries` | `FWCI_BINARIES` |
| `TOKEN`, `EMAIL`, `PASSWORD` | `token`, `email`, `password` | `FWCI_TOKEN`, `FWCI_EMAIL`, `FWCI_PASSWORD` |
| `ORGANIZATION` | `organization` | `FWCI_ORG` |
| `API` | `api` | `FWCI_API` |
| `GITLAB_TOKEN` | | `FWCI_GITLAB_TOKEN` |
| `PRIORITY` | `priority` | `--priority` in `FWCI_ARGS` |
| `BRANCH` | `branch` | `-b` in `FWCI_ARGS` |
| `PROJECT_LINK` | `project_link` | `--project-link` in `FWCI_ARGS` |
| `COMMIT_HASH` | `commit_hash` | `--commit` in `FWCI_ARGS` |
| `ACTION` | `action` | `--action` in `FWCI_ARGS` |
| `GITHUB_INSTALLATION_ID` | `github_installation_id` | |
| `CI` | gone, fwci tells the CI itself | gone |

## Development

`action.yml` is a composite action, `Dockerfile` the fwci image for GitLab, which `docker.yml` publishes daily
as `firmwareci/action:v8` and under the fwci version it holds. The `Action` workflow runs the action locally
against `test/fixture`, a mock DUT, and on the FirmwareCI dev API with the `FWCI_DEV_TOKEN` secret.

## License

BSD 2-Clause, see [LICENSE](LICENSE).
