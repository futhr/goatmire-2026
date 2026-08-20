# Goatmire teaching notebooks

These notebooks are the tutorial companion to **Zero Alert Storms: Formal Verification for IoT Automation**. They are written for an IoT engineer who knows Elixir but is new to Maude.

Work through them in order:

1. [`01_terms_equations_and_rules.livemd`](./01_terms_equations_and_rules.livemd) builds the Maude mental model without a fleet or broker.
2. [`02_conflicts_are_about_composition.livemd`](./02_conflicts_are_about_composition.livemd) reads real automation rules and detects direct and cascading interactions.
3. [`03_the_deployment_gate.livemd`](./03_the_deployment_gate.livemd) turns a verdict into a fail-closed deployment decision.
4. [`04_agent_policy_same_mechanism.livemd`](./04_agent_policy_same_mechanism.livemd) applies the same method to structured agent policies.

The shorter notebooks in `priv/livebooks/` are stage scenarios. They optimise for a predictable live demonstration. These optimise for understanding.

## Running them

The Docker stack opens Livebook at <http://localhost:8080> and exposes this directory as `tutorials/`. It attaches to the running Goatmire node, so the application and its four-worker ExMaude pool are already available.

From a local Livebook, open a notebook from this repository and connect a runtime. Its setup cell installs the local Goatmire project only when the modules are not already loaded.

No notebook requires physical hardware. The interpreter is real; the fleet is simulated; every clean verdict is explicitly limited to the detector's model.
