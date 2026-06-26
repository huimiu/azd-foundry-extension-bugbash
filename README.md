# AZD Foundry Extension Bug Bash

> **Unsigned local test builds — not official releases.** Share only with people
> you trust; do not use in production.

## Main features in this build

Everything models a Foundry project directly in **`azure.yaml`** — no separate
`agent.yaml` / `agent.manifest.yaml`.

- **Unified `azure.yaml` & resource modeling** — the project, model deployments,
  connections, toolboxes, skills, agents, and routines are each a `services:`
  entry with its own `host:`, wired together with `uses:`.
- **`$ref` file includes** — split large entries into their own files and pull
  them in with `$ref`, with sibling keys layered on top as overrides.
- **IaC-less & flexible init** — `azd ai agent init` scaffolds without an `infra/`
  folder (Bicep-less), with Terraform as an option (`--infra terraform`) and an
  `--image` flag for prebuilt agent images.
- **Secure-by-default private networking** — VNet-bound (network-secured) Foundry
  accounts configured straight from `azure.yaml`.

## What's inside

| Folder | What it is |
|---|---|
| `azd-foundry-core/` | The patched **azd CLI** (`azd.exe`, `1.27.0-beta.1-pr.foundrytest3`) |
| `foundry-registry/` | All **8 Foundry extensions** + a one-command installer |

This feature spans **both** core and extensions, so you need **both** folders.

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

Each Foundry resource is its **own top-level `services:` entry** — siblings, not
nested — with a singular `host:`, keyed by its name, and wired with `uses:`:

| `host:` | Owns | Has source? |
|---|---|---|
| `azure.ai.project` | the project + its `deployments:` (and optional `endpoint:` / `network:`) | no |
| `azure.ai.connection` | one connection | no |
| `azure.ai.toolbox` | one toolbox | no |
| `azure.ai.skill` | one skill | no |
| `azure.ai.agent` | one agent (`kind: hosted`) | yes |
| `azure.ai.routine` | one scheduled/event routine | no |

There is **one service per resource** — add another entry for each connection,
toolbox, skill, agent, or routine you want. Only `deployments:` stays an array
(on the single `azure.ai.project` service, since deployments belong to the
project). Services are ordered with `uses:`, and resources reference each other
by name across service boundaries.

Samples to copy from:

- [`unified-yaml-sample/azure.yaml`](./unified-yaml-sample/azure.yaml) — the
  minimal "project + agent" shape in this kit.
- [`simple.azure.yaml`](https://github.com/Azure/azure-dev/blob/huimiu/foundry-azure-yaml/cli/azd/extensions/azure.ai.agents/schemas/examples/simple.azure.yaml)
  / [`complex.azure.yaml`](https://github.com/Azure/azure-dev/blob/huimiu/foundry-azure-yaml/cli/azd/extensions/azure.ai.agents/schemas/examples/complex.azure.yaml)
  — the feature branch's own canonical examples (minimal and everything-wired).

Design references: [PR #8590](https://github.com/Azure/azure-dev/pull/8590) and
the separate-services write-up
([README](https://github.com/therealjohn/foundry-azd-config-preview/blob/separate-services/README.md)
/ [REFERENCE](https://github.com/therealjohn/foundry-azd-config-preview/blob/separate-services/REFERENCE.md)).
The REFERENCE is illustrative — where its agent shape differs (`docker:`/`runtime:`/`image:`,
`kind: prompt`), the **shapes below match this build's schema** and are what azd here actually reconciles.

> ✅ **Schema note:** the feature branch's root schema now `$ref`s all the
> `azure.ai.*` sub-schemas from the branch itself, so the editor should resolve
> the full unified shape. This build of `azd` also writes the **feature-branch**
> schema URL into files it generates (e.g. `azd ai agent init`), so they validate
> too. If you see unresolved-`$ref` warnings, reload your editor window to refetch.

### Templating: `${VAR}` vs `${{...}}`

- `${VAR}` — azd environment substitution, resolved **client-side** from
  `.azure/<env>/.env` (e.g. `target: ${SEARCH_ENDPOINT}`).
- `${{...}}` — passed through **untouched** for Foundry to resolve **server-side**
  (e.g. `env: { MODEL_ENDPOINT: ${{project.endpoint}} }`).

## Resource catalog (real shapes)

Copy entries into your `azure.yaml`. Every snippet is a `services:` excerpt;
each resource is its own entry keyed by name. **Reference vs. declare:** declare
a resource only if azd should create/upsert it. To use a resource created
elsewhere (Portal, `az`, another tool), **don't declare it** — just reference it
by name from a toolbox/agent, and azd verifies it exists at deploy.

### Project + model deployments

```yaml
services:
  ai-project:
    host: azure.ai.project
    # endpoint: ${FOUNDRY_PROJECT_ENDPOINT}   # set => reuse an existing project (skip provision)
    deployments:
      - name: gpt-4o-mini
        model: { format: OpenAI, name: gpt-4o-mini, version: "2024-07-18" }
        sku:   { name: GlobalStandard, capacity: 10 }
      # - $ref: ./deployments/embeddings.yaml   # a deployment can live in its own file
```

The **presence** of `endpoint:` is the signal that the project already exists:
`azd provision` skips ARM provisioning and connects; `azd deploy` only reconciles
data-plane state and pushes agents. Omit it to provision a new project.

### Connection

```yaml
  github-mcp-conn:
    host: azure.ai.connection
    uses: [ai-project]
    category: CustomKeys                 # CustomKeys | ApiKey | AzureOpenAI | CognitiveSearch | RemoteTool
    target: https://api.githubcopilot.com/mcp
    authType: CustomKeys                 # ApiKey | CustomKeys | ProjectManagedIdentity | AAD | ManagedIdentity | ...
    credentials:
      x-api-key: ${GITHUB_MCP_TOKEN}     # ${VAR} from .env, or ${{...}} for server-side
    metadata:
      type: custom_MCP
```

`authType: ProjectManagedIdentity` keeps **no secret on disk** — omit
`credentials:` and the project's managed identity authenticates to the target
(best for Azure-to-Azure connections).

### Toolbox

```yaml
  research-tools:
    host: azure.ai.toolbox
    uses: [ai-project, search-conn]
    description: Tools for research agents.
    tools:
      - type: code_interpreter
      - type: web_search
      - type: azure_ai_search
        connection: search-conn          # connection-backed tools name their connection
      - type: mcp
        connection: github-mcp-conn
```

One toolbox can be referenced by **multiple agents** — the project-scoped sharing
the old per-agent `agent.manifest.yaml` couldn't do.

### Skill

```yaml
  summarize:
    host: azure.ai.skill
    uses: [ai-project]
    description: Summarize long documents.
    instructions: ./skills/summarize.md   # file-backed; or inline with `instructions: |`
    tools: [code_interpreter]
```

### Agent (`kind: hosted`)

```yaml
  assistant:
    host: azure.ai.agent
    project: ./agents/assistant           # agent source dir (azd service field)
    uses: [ai-project]
    kind: hosted                          # only `hosted` in this build
    name: assistant
    description: A simple assistant.
    # ---- optional ----
    codeConfiguration:                    # code-deploy (ZIP) instead of a container
      runtime: python_3_12                # e.g. python_3_12, dotnet_9
      entryPoint: main.py
      dependencyResolution: remote_build  # bundled | remote_build
    protocols:
      - { protocol: responses, version: "1.0.0" }
    container:
      resources: { cpu: "0.5", memory: 1Gi }
    toolboxes: [research-tools]           # reference toolboxes by name
    skill: summarize                      # a "prompt-style" agent is a hosted agent backed by a skill
    env:
      FOUNDRY_MODEL_DEPLOYMENT_NAME: gpt-4o-mini
```

`kind: hosted` is the only agent kind in this build. A prompt-style agent is just
a hosted agent backed by a `skill:` and minimal source. Drop in `codeConfiguration:`
to deploy from source (ZIP); leave it out and azd infers the build from the
`project:` dir (`main.py` + `requirements.txt`).

### Routine

```yaml
  nightly-digest:
    host: azure.ai.routine
    uses: [researcher]                    # the agent it invokes
    description: Summarize the day's documents every night.
    triggers:
      default:
        type: schedule
        cron_expression: "0 2 * * *"
    action:
      type: invoke_agent_responses_api
      agent_name: researcher
      input:
        topic: ${DIGEST_TOPIC}
```

Event-driven variant — swap the trigger:

```yaml
    triggers:
      default:
        type: event
        filter: { source: blob, eventType: Microsoft.Storage.BlobCreated }
```

The [`complex.azure.yaml`](https://github.com/Azure/azure-dev/blob/huimiu/foundry-azure-yaml/cli/azd/extensions/azure.ai.agents/schemas/examples/complex.azure.yaml)
example wires all of the above together — copy from it. CLI entry points:
`azd ai connection`, `azd ai toolbox`, `azd ai skill`, `azd ai routine`,
`azd ai agent`.

## Things to try

Each item is independent — pick any. Items marked **(no Azure)** need only the
editor / CLI; the rest need an Azure subscription + Foundry access.

### Schema validation in the editor (no Azure)

1. Open the repo in **VS Code** (with the YAML extension) and open
   [`unified-yaml-sample/azure.yaml`](./unified-yaml-sample/azure.yaml).
2. Confirm the `# yaml-language-server: $schema=…` line resolves and you get
   autocomplete on `host:` values and inside `deployments:` / the agent fields.
3. Break things and confirm red squiggles: misspell `host: azure.ai.projct`, put
   `deployments:` under the agent, or add an unknown field.

### `azd ai agent init` writes one file (no Azure)

1. Make a fresh directory **outside this repo** — anywhere that is *not* nested
   under a folder containing an `azure.yaml`. (azd discovers projects by walking
   **up** the directory tree, so if you run this inside `unified-yaml-sample/`
   it finds that sample project and adds the agent to it instead of creating a
   new one.) Then run `azd ai agent init`.
2. Confirm it writes a unified `azure.yaml` with `services:` entries (a
   `host: azure.ai.project` service and a `host: azure.ai.agent` service), and
   does **not** create `agent.yaml` or `agent.manifest.yaml`.

### `$ref` file includes (no Azure)

Split a service body into its own file and reference it from `azure.yaml`. Keys
placed next to `$ref` override the loaded file:

```yaml
services:
  assistant:
    host: azure.ai.agent
    uses: [ai-project]
    $ref: ./agents/assistant.yaml             # body loaded from the file
    description: Overrides the file's description.   # sibling override
```

`$ref` works for deployments, skills, and agents too (see `complex.azure.yaml`).
Check: relative paths inside the loaded file (`project:`, `instructions:`) rebase
to that file's own folder, and a bad/unreadable path gives a clear error.

### IaC-less init, Terraform, and prebuilt images

```powershell
azd ai agent init                              # Bicep-less: no infra/ folder needed
azd ai agent init --infra terraform            # scaffold Terraform instead of Bicep
azd ai agent init --image <registry/image:tag> # use a prebuilt agent image (skip build)
```

Check: a Foundry-only project provisions with **no `infra/` folder**; `--infra
terraform` writes a `.tf` module; `--image` skips the source build at deploy.

### Provision & deploy (needs Azure)

> The placeholder agent under `unified-yaml-sample/agents/assistant` is
> intentionally minimal — it exercises the **orchestration**, not a real agent
> runtime. For a guaranteed-runnable agent, scaffold one with `azd ai agent sample`
> (or [aka.ms/foundry-agents-samples](https://aka.ms/foundry-agents-samples)) and
> point the `assistant` service's `project:` at it.

```powershell
cd unified-yaml-sample
azd auth login
azd env new foundry-bugbash
azd up            # provision (project) + deploy (agents), or run provision/deploy separately
```

azd walks the services in `uses:` order. End-to-end lifecycle:

| Command | Effect |
|---|---|
| `azd provision` | The `ai-project` service creates the Foundry project (in-memory Bicep) + its model deployments. |
| `azd deploy` | Walks services in `uses:` order: connection / toolbox / skill / routine services reconcile via Foundry APIs; then each agent service builds + pushes (ACR) and posts its agent version. |
| `azd up` | Both, in order. |
| `azd down` | Destroys what azd provisioned. An `endpoint:`-based (existing) project is **not** deleted. |

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
- **Reference vs. declare.** Reference a toolbox/connection by name without
  declaring it and confirm azd verifies (not recreates) it at deploy.
- **Teardown.** `azd down` removes what azd provisioned; an `endpoint:`-based
  project should NOT be deleted.

### Secure-by-default private networking (needs Azure)

Add a `network:` block to the `azure.ai.project` service to provision a VNet-bound
(network-secured) account. Omit it for a public account.

```yaml
services:
  ai-project:
    host: azure.ai.project
    network:
      agentSubnet: { vnet: ${AZURE_VNET_ID}, name: agent-subnet, prefix: 192.168.0.0/24 }
      peSubnet:    { vnet: ${AZURE_VNET_ID}, name: pe-subnet,    prefix: 192.168.1.0/24 }
      dns:         { resourceGroup: rg-private-dns, subscription: ${AZURE_DNS_SUBSCRIPTION_ID} }
    deployments:
      - name: gpt-4o-mini
        model: { format: OpenAI, name: gpt-4o-mini, version: "2024-07-18" }
        sku:   { name: GlobalStandard, capacity: 10 }
```

Omit `agentSubnet` to use the Microsoft-managed network; `peSubnet` (the account
private endpoint) establishes the private data plane with public access disabled.
Check: provision creates a network-secured account with public access disabled.
More detail in the agents extension's `docs/private-networking.md`.

### Migration from the old shape (no Azure)

1. `cd unified-yaml-sample/migration-before`
2. Run `azd package`.
3. [`migration-before/azure.yaml`](./unified-yaml-sample/migration-before/azure.yaml)
   uses the OLD config-nested agent shape (agent fields under `config:`) — confirm
   azd prints a **deprecation warning** pointing at the migration guide, and does
   not crash.

### How to report findings

File issues at [https://github.com/Azure/azure-dev/issues](https://github.com/Azure/azure-dev/issues).
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
