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

## Now you're ready

```powershell
azd ai agent init
azd up
```

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
