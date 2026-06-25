# Bug bash: unified `azure.yaml` for Foundry

This folder is a ready-to-poke sample for testing the **unified `azure.yaml`**
feature — the one where a whole Foundry project (the project, its model
deployments, connections, toolboxes, skills, agents, and routines) is described
as a set of `services:` entries in a **single `azure.yaml`**, instead of separate
`agent.yaml` / `agent.manifest.yaml` files.

Design reference: [PR #8590 — technical design spec](https://github.com/Azure/azure-dev/pull/8590).

## The idea in one screen

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

See [`azure.yaml`](./azure.yaml) in this folder for the minimal "project + agent"
shape.

## Prerequisites

Install the test build first (see the repo root [README](../README.md)):

```powershell
azd version            # -> 1.27.0-beta.1-pr.foundrytest1
azd extension list     # azure.ai.* + microsoft.foundry at *-foundrytest.1
```

---

## Tier 1 — authoring & schema (no Azure needed)

The fastest, highest-value bug bash. None of this spends Azure.

### 1a. Schema validation in the editor

1. Open this folder in **VS Code** (with the YAML extension) and open
   [`azure.yaml`](./azure.yaml).
2. Confirm the `# yaml-language-server: $schema=…` line resolves and you get:
   - autocomplete on `host:` values (`azure.ai.project`, `azure.ai.agent`, …),
   - autocomplete/validation inside `deployments:` and the agent fields.
3. Intentionally break things and confirm you get a red squiggle:
   - misspell `host: azure.ai.projct`,
   - put `deployments:` under the agent instead of the project,
   - add an unknown field.

> ⚠️ **Known issue (please still note it):** the feature branch's root schema
> currently `$ref`s the `azure.ai.project / connection / toolbox / skill / routine`
> sub-schemas from `main`, where they don't exist yet (HTTP 404). So today the
> editor validates the top-level structure, `host:` enum, and the **agent**
> fields, but the **project/connection/toolbox/skill/routine** detail (e.g. the
> `deployments:` item shape) may show as unresolved. This is a schema-wiring bug
> on the branch, not your setup.

### 1b. `azd ai agent init` writes ONE file

1. In an **empty** directory, run:
   ```powershell
   azd ai agent init
   ```
2. Confirm it writes a unified `azure.yaml` with `services:` entries (a
   `host: azure.ai.project` service and a `host: azure.ai.agent` service), and
   does **not** create `agent.yaml` or `agent.manifest.yaml`.
3. Compare against [`azure.yaml`](./azure.yaml) here — same shape?

### 1c. Migration / deprecation warning

1. `cd migration-before`
2. Run a command that loads the project, e.g.:
   ```powershell
   azd package
   ```
3. [`migration-before/azure.yaml`](./migration-before/azure.yaml) uses the OLD
   config-nested agent shape. Confirm azd prints a **deprecation warning** that
   points at the migration guide — and does not crash.

---

## Tier 2 — provision & deploy (needs an Azure subscription + Foundry access)

> The placeholder agent under `agents/assistant` is intentionally minimal — it
> exercises the **orchestration**, not a real agent runtime. For a
> guaranteed-runnable agent, scaffold one with `azd ai agent sample` (or
> [aka.ms/foundry-agents-samples](https://aka.ms/foundry-agents-samples)) and
> point the `assistant` service's `project:` at it.

```powershell
azd auth login
azd env new foundry-bugbash
azd provision     # creates the Foundry project (host: azure.ai.project)
azd deploy        # walks services in `uses:` order; deploys the agent
# or both at once:
azd up
```

Things to look for / try to break:

- **Per-service progress.** With multiple services, azd should show progress and
  success/failure **per service** (the project, then each agent), not one opaque step.
- **`uses:` ordering.** The project should reconcile before the agent. Remove the
  `uses: [ai-project]` edge and see whether deploy order / behavior degrades.
- **Failure attribution.** Break one service (e.g. a bad `model.version`) and
  confirm the error names the failing service and stops downstream work.
- **Re-run safety.** Run `azd deploy` again; finished work should be detected and
  upserted, not duplicated.
- **Existing project reuse.** Add `endpoint: <your project endpoint>` to the
  `ai-project` service and confirm azd connects instead of provisioning.
- **Teardown.** `azd down` should remove what azd provisioned; an `endpoint:`-based
  project should NOT be deleted.

---

## Want the full surface?

The simple sample here covers project + agent. For connections, toolboxes,
skills, prompt agents, routines, inline tools, and `$ref` file includes, see the
canonical `complex` example on the branch:
[`cli/azd/extensions/azure.ai.agents/schemas/examples/complex.azure.yaml`](https://github.com/Azure/azure-dev/blob/huimiu/foundry-azure-yaml/cli/azd/extensions/azure.ai.agents/schemas/examples/complex.azure.yaml).

## How to report findings

File issues at <https://github.com/huimiu/azd-foundry-extension-bugbash/issues>
(or your team's tracker). Please include:

- `azd version` and `azd extension list` output,
- the `azure.yaml` you used (or a diff from this sample),
- the command, the full output, and what you expected.
