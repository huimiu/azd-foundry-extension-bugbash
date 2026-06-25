#!/usr/bin/env bash
# Installs the Foundry feature-branch test extensions from this folder.
# Localizes artifact paths to this folder, registers a 'foundrytest' file source,
# and installs the microsoft.foundry meta-package (pulls all 7 azure.ai.* deps
# from the same source).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
reg="$root/registry.json"
local="$root/registry.local.json"

echo "Localizing artifact paths to: $root"
if command -v node >/dev/null 2>&1; then
  ROOT="$root" REG="$reg" OUT="$local" node -e '
    const fs=require("fs");
    const r=JSON.parse(fs.readFileSync(process.env.REG,"utf8"));
    for(const e of r.extensions) for(const v of (e.versions||[])){
      const a=v.artifacts||{};
      for(const k of Object.keys(a)){
        const u=a[k].url;
        if(u && !/^https?:\/\//.test(u) && u[0] !== "/") a[k].url = process.env.ROOT + "/" + u;
      }
    }
    fs.writeFileSync(process.env.OUT, JSON.stringify(r,null,2));
  '
elif command -v python3 >/dev/null 2>&1; then
  ROOT="$root" REG="$reg" OUT="$local" python3 - <<'PY'
import json,os
r=json.load(open(os.environ["REG"]))
root=os.environ["ROOT"]
for e in r["extensions"]:
  for v in e.get("versions",[]):
    for k,a in (v.get("artifacts") or {}).items():
      u=a.get("url","")
      if u and not u.startswith(("http://","https://","/")):
        a["url"]=root+"/"+u
json.dump(r,open(os.environ["OUT"],"w"),indent=2)
PY
else
  echo "ERROR: need node or python3 to localize paths." >&2; exit 1
fi

echo "Registering 'foundrytest' extension source..."
azd extension source remove foundrytest 2>/dev/null || true
azd extension source add -n foundrytest -t file -l "$local"

echo "Installing microsoft.foundry (and its 7 dependencies)..."
azd extension install microsoft.foundry --source foundrytest

echo
echo "Done. Verify with:  azd extension list"
