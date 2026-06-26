# AZD Foundry Extension Bug Bash

> **Unsigned local test builds — not official releases.** Share only with people
> you trust; do not use in production.

You're testing the **unified `azure.yaml`**: you describe a whole Foundry project
— the project, model deployments, connections, toolboxes, skills, agents, and
routines — as `services:` entries in **one file**, then drive it with the azd
commands you already know (`azd ai agent init`, `azd up`, `azd down`). No more
`agent.yaml` / `agent.manifest.yaml`.

This guide is a checklist: each section is **a thing to try**, the **exact
command**, and **what you should see**. Items marked **(no Azure)** need only the
editor / CLI; the rest need an Azure subscription + Foundry access. Pick any —
they're independent.

## Setup (two steps)

### 1. Put azd on PATH

```powershell
cd azd-foundry-core
$env:PATH = "$PWD;$env:PATH"   # this shell only; or add the folder to PATH permanently
azd version                    # -> 1.27.0-beta.1-pr.foundrytest3
cd ..
```

If SmartScreen warns about an unknown publisher: **More info → Run anyway**.

### 2. Install the extensions

```powershell
.\foundry-registry\install-foundry.ps1
azd extension list
```

✅ **Expect:** every `azure.ai.*` + `microsoft.foundry` shows a `*-foundrytest.1`
version with source `foundrytest`.

## Try it

### 1. Scaffold a project (no Azure)

Make a fresh directory **outside this repo** — anywhere *not* nested under a
folder that already contains an `azure.yaml` (azd discovers projects by walking
**up** the tree, so running it inside `unified-yaml-sample/` would add the agent
to that project instead of making a new one).

```powershell
mkdir my-foundry-app; cd my-foundry-app
azd ai agent init
```

✅ **Expect:** one `azure.yaml` with `services:` entries (a `host: azure.ai.project`
service and a `host: azure.ai.agent` service) plus the agent source. **No**
`agent.yaml`, **no** `agent.manifest.yaml`, and **no** `infra/` folder (Bicep-less
by default).

### 2. See it validate in the editor (no Azure)

Open [`unified-yaml-sample/azure.yaml`](./unified-yaml-sample/azure.yaml) in
**VS Code** (with the YAML extension).

✅ **Expect:** the `# yaml-language-server: $schema=…` line resolves; you get
autocomplete on `host:` values and inside `deployments:` / the agent fields.
Now break it — misspell `host: azure.ai.projct`, move `deployments:` under the
agent, or add an unknown field — and **expect red squiggles**.

### 3. Provision & deploy (needs Azure)

> The placeholder agent under `unified-yaml-sample/agents/assistant` is
> intentionally minimal — it exercises the **orchestration**, not a real runtime.
> For a guaranteed-runnable agent, scaffold one with `azd ai agent sample` (or
> [aka.ms/foundry-agents-samples](https://aka.ms/foundry-agents-samples)) and
> point the `assistant` service's `project:` at it.

```powershell
cd unified-yaml-sample
azd auth login
azd env new foundry-bugbash
azd up
```

✅ **Expect:** azd walks the services in `uses:` order — it **provisions the
project + model deployment first**, then **deploys the agent** — and shows
**progress per service**, not one opaque step. On success it prints the project /
agent endpoint. (`azd up` = `azd provision` + `azd deploy`; you can run them
separately.)

### 4. Re-run safely (needs Azure)

```powershell
azd deploy
```

✅ **Expect:** running deploy again **upserts** — finished work is reconciled, not
duplicated.

### 5. Watch failure attribution (needs Azure)

Edit `ai-project`'s deployment to a bad `model.version`, then:

```powershell
azd provision
```

✅ **Expect:** the error **names the failing service** (`ai-project`) and stops
downstream work — the agent isn't deployed against a broken project.

### 6. Reuse an existing project (needs Azure)

Add an `endpoint:` to the `ai-project` service in `azure.yaml`:

```yaml
  ai-project:
    host: azure.ai.project
    endpoint: ${FOUNDRY_PROJECT_ENDPOINT}   # set it in .azure/<env>/.env
```

```powershell
azd provision
```

✅ **Expect:** the **presence of `endpoint:`** makes azd **connect to the existing
project and skip ARM provisioning**; `azd deploy` only reconciles data-plane state
and pushes agents. Later, `azd down` must **not** delete an `endpoint:`-based
project.

### 7. Add more resources (needs Azure)

A toolbox, connection, skill, routine, or second agent is just **another
`services:` entry**. Copy one from the fully-wired
[`complex.azure.yaml`](https://github.com/Azure/azure-dev/blob/huimiu/foundry-azure-yaml/cli/azd/extensions/azure.ai.agents/schemas/examples/complex.azure.yaml)
into your `azure.yaml`, wire it with `uses:`, then:

```powershell
azd deploy
```

✅ **Expect:** each new service gets **its own progress line** and reconciles in
`uses:` order (connections/toolboxes/skills before the agents that use them). One
toolbox can be shared by **multiple agents** — something the old per-agent
`agent.manifest.yaml` couldn't do. You can also drive each resource from its CLI:
`azd ai connection`, `azd ai toolbox`, `azd ai skill`, `azd ai routine`,
`azd ai agent`.

### 8. Init without Bicep, or with Terraform / a prebuilt image (no Azure)

```powershell
azd ai agent init                              # Bicep-less: no infra/ folder
azd ai agent init --infra terraform            # scaffold Terraform instead
azd ai agent init --image <registry/image:tag> # use a prebuilt image, skip the build
```

✅ **Expect:** a Foundry-only project scaffolds with **no `infra/` folder**;
`--infra terraform` writes a `.tf` module; `--image` **skips the source build** at
deploy.

### 9. Split a file with `$ref` (no Azure)

Move a service body into its own file and reference it; keys next to `$ref`
override the loaded file:

```yaml
services:
  assistant:
    host: azure.ai.agent
    uses: [ai-project]
    $ref: ./agents/assistant.yaml             # body loaded from the file
    description: Overrides the file's description.   # sibling override wins
```

✅ **Expect:** the body loads from the file, the sibling `description:` **overrides**
it, relative paths inside the file (`project:`, `instructions:`) **rebase to that
file's folder**, and a bad/unreadable path gives a **clear error**. `$ref` also
works for deployments, skills, and agents (see `complex.azure.yaml`).

### 10. Turn on private networking (needs Azure)

Add a `network:` block to the `azure.ai.project` service (omit it for a public
account):

```yaml
  ai-project:
    host: azure.ai.project
    network:
      agentSubnet: { vnet: ${AZURE_VNET_ID}, name: agent-subnet, prefix: 192.168.0.0/24 }
      peSubnet:    { vnet: ${AZURE_VNET_ID}, name: pe-subnet,    prefix: 192.168.1.0/24 }
    deployments:
      - name: gpt-4o-mini
        model: { format: OpenAI, name: gpt-4o-mini, version: "2024-07-18" }
        sku:   { name: GlobalStandard, capacity: 10 }
```

```powershell
azd provision
```

✅ **Expect:** a **VNet-bound, network-secured account with public access
disabled**. (Omit `agentSubnet` to use the Microsoft-managed network.) More detail
in the agents extension's `docs/private-networking.md`.

### 11. Confirm the old shape still warns (no Azure)

```powershell
cd unified-yaml-sample/migration-before
azd package
```

✅ **Expect:** [`migration-before/azure.yaml`](./unified-yaml-sample/migration-before/azure.yaml)
uses the OLD config-nested agent shape (agent fields under `config:`) — azd prints
a **deprecation warning** pointing at the migration guide and **does not crash**.

### 12. Tear it all down (needs Azure)

```powershell
azd down
```

✅ **Expect:** azd removes what **it** provisioned (project + deployments +
agents). A project you brought via `endpoint:` is **left untouched**.

## How to report findings

File issues at [https://github.com/Azure/azure-dev/issues](https://github.com/Azure/azure-dev/issues).
Please include `azd version` + `azd extension list` output, the `azure.yaml` you
used, the command, the full output, and what you expected.

Design references (for context, not how-to):
[PR #8590](https://github.com/Azure/azure-dev/pull/8590) and the separate-services
write-up ([README](https://github.com/therealjohn/foundry-azd-config-preview/blob/separate-services/README.md)
/ [REFERENCE](https://github.com/therealjohn/foundry-azd-config-preview/blob/separate-services/REFERENCE.md)).

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
