# azd Foundry — feature-branch test build

> **Unsigned local test builds — not official releases.** Share only with people
> you trust; do not use in production.

## What's inside

| Folder | What it is |
|---|---|
| `azd-foundry-core/` | The patched **azd CLI** (`azd.exe`, `1.27.0-beta.1-pr.foundrytest1`) |
| `foundry-registry/` | All **8 Foundry extensions** + a one-command installer |

This feature spans **both** core and extensions, so you need **both** folders.

## Setup (two steps)

### 1. Put azd on PATH

```powershell
cd azd-foundry-core
$env:PATH = "$PWD;$env:PATH"   # this shell only; or add the folder to PATH permanently
azd version                    # -> 1.27.0-beta.1-pr.foundrytest1
cd ..
```

If SmartScreen warns about an unknown publisher: **More info → Run anyway**.

### 2. Install the extensions

```powershell
.\foundry-registry\install-foundry.ps1
```

This registers a local `foundrytest` source and installs `microsoft.foundry`,
which pulls in all 7 `azure.ai.*` extensions. Verify:

```powershell
azd extension list
```

Every `azure.ai.*` + `microsoft.foundry` should show a `*-foundrytest.1` version
with source `foundrytest`.

## Bug bash: unified `azure.yaml`

The feature under test is the **unified `azure.yaml`** — a whole Foundry project
(the project, its model deployments, connections, toolboxes, skills, agents, and
routines) described as `services:` entries in **one file**, instead of separate
`agent.yaml` / `agent.manifest.yaml`.

Each Foundry resource is its own `services:` entry with a singular `host:`, keyed
by its name, and wired with `uses:`:

| `host:` | Owns | Has source? |
|---|---|---|
| `azure.ai.project` | the project + its `deployments:` (and optional `endpoint:`) | no |
| `azure.ai.connection` | one connection | no |
| `azure.ai.toolbox` | one toolbox | no |
| `azure.ai.skill` | one skill | no |
| `azure.ai.agent` | one agent (`kind: hosted` or `prompt`) | yes (hosted) |
| `azure.ai.routine` | one scheduled/event routine | no |

A ready-to-poke sample lives in [`unified-yaml-sample/`](./unified-yaml-sample/):
[`azure.yaml`](./unified-yaml-sample/azure.yaml) is the minimal "project + agent"
shape. Design reference: [PR #8590](https://github.com/Azure/azure-dev/pull/8590).

> ✅ **Schema note:** the feature branch's root schema now `$ref`s all the
> `azure.ai.*` sub-schemas from the branch itself, so the editor should resolve
> the full unified shape. If you see unresolved-`$ref` warnings, reload your
> editor window to refetch the schema.

### Without Azure: authoring & schema

The fastest checks — none of this spends Azure.

**Schema validation in the editor**

1. Open the repo in **VS Code** (with the YAML extension) and open
   [`unified-yaml-sample/azure.yaml`](./unified-yaml-sample/azure.yaml).
2. Confirm the `# yaml-language-server: $schema=…` line resolves and you get
   autocomplete on `host:` values and inside `deployments:` / the agent fields.
3. Break things and confirm red squiggles: misspell `host: azure.ai.projct`, put
   `deployments:` under the agent, or add an unknown field.

**`azd ai agent init` writes ONE file**

1. In an **empty** directory, run `azd ai agent init`.
2. Confirm it writes a unified `azure.yaml` with `services:` entries (a
   `host: azure.ai.project` service and a `host: azure.ai.agent` service), and
   does **not** create `agent.yaml` or `agent.manifest.yaml`.

**Migration / deprecation warning**

1. `cd unified-yaml-sample/migration-before`
2. Run `azd package`.
3. [`migration-before/azure.yaml`](./unified-yaml-sample/migration-before/azure.yaml)
   uses the OLD config-nested agent shape — confirm azd prints a **deprecation
   warning** pointing at the migration guide, and does not crash.

### With Azure: provision & deploy

Needs an Azure subscription + Foundry access.

> The placeholder agent under `unified-yaml-sample/agents/assistant` is
> intentionally minimal — it exercises the **orchestration**, not a real agent
> runtime. For a guaranteed-runnable agent, scaffold one with `azd ai agent sample`
> (or [aka.ms/foundry-agents-samples](https://aka.ms/foundry-agents-samples)) and
> point the `assistant` service's `project:` at it.

```powershell
cd unified-yaml-sample
azd auth login
azd env new foundry-bugbash
azd up            # provision (project) + deploy (agent), or run provision/deploy separately
```

Things to look for / try to break:

- **Per-service progress.** With multiple services, azd shows progress and
  success/failure **per service**, not one opaque step.
- **`uses:` ordering.** The project reconciles before the agent. Remove the
  `uses: [ai-project]` edge and see whether deploy order/behavior degrades.
- **Failure attribution.** Break one service (e.g. a bad `model.version`) and
  confirm the error names the failing service and stops downstream work.
- **Re-run safety.** Run `azd deploy` again; finished work should upsert, not
  duplicate.
- **Existing project reuse.** Add `endpoint: <your project endpoint>` to the
  `ai-project` service and confirm azd connects instead of provisioning.
- **Teardown.** `azd down` removes what azd provisioned; an `endpoint:`-based
  project should NOT be deleted.

### The full surface

The sample covers project + agent. For connections, toolboxes, skills, prompt
agents, routines, inline tools, and `$ref` file includes, see the canonical
`complex` example on the branch:
[`complex.azure.yaml`](https://github.com/Azure/azure-dev/blob/huimiu/foundry-azure-yaml/cli/azd/extensions/azure.ai.agents/schemas/examples/complex.azure.yaml).

### How to report findings

File issues at [<https://github.com/huimiu/azd-foundry-extension-bugbash/issues](https://github.com/Azure/azure-dev/issues)>.
Please include `azd version` + `azd extension list` output, the `azure.yaml` you
used, the command, the full output, and what you expected.

## Extension versions

| Extension | Version |
|---|---|
| azure.ai.agents | `0.1.42-preview-foundrytest.1` |
| azure.ai.connections | `0.1.3-preview-foundrytest.1` |
| azure.ai.toolboxes | `0.1.2-preview-foundrytest.1` |
| azure.ai.routines | `0.1.1-preview-foundrytest.1` |
| azure.ai.skills | `0.1.1-preview-foundrytest.1` |
| azure.ai.projects | `0.1.1-preview-foundrytest.1` |
| azure.ai.inspector | `0.0.1-preview-foundrytest.1` |
| microsoft.foundry (meta) | `0.1.0-preview-foundrytest.1` |

## Revert to production

```powershell
azd extension uninstall microsoft.foundry
azd extension source remove foundrytest
azd extension install microsoft.foundry      # production version from default source
# and remove azd-foundry-core from PATH / use your stock azd
```
