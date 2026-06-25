# Minimal placeholder agent entrypoint for the bug bash.
#
# The unified-YAML feature under test is about azure.yaml authoring and the
# provision/deploy orchestration — NOT this file's contents. For a
# guaranteed-runnable hosted agent, scaffold one with `azd ai agent sample`
# (or browse https://aka.ms/foundry-agents-samples) and point the
# `assistant` service's `project:` at it.

import os


def main() -> None:
    deployment = os.environ.get("FOUNDRY_MODEL_DEPLOYMENT_NAME", "unset")
    print(f"assistant agent starting; model deployment = {deployment}")


if __name__ == "__main__":
    main()
