# Goatmire teaching notebooks

These notebooks are the tutorial companion to **Zero Alert Storms: Formal Verification for IoT Automation**. They are written for an IoT engineer who knows Elixir but is new to Maude.

Work through them in order:

1. [`01_terms_equations_and_rules.livemd`](./01_terms_equations_and_rules.livemd) builds the Maude mental model without a fleet or broker.
2. [`02_conflicts_are_about_composition.livemd`](./02_conflicts_are_about_composition.livemd) reads real automation rules and detects direct and cascading interactions.
3. [`03_the_deployment_gate.livemd`](./03_the_deployment_gate.livemd) turns a verdict into a fail-closed deployment decision.
4. [`04_agent_policy_same_mechanism.livemd`](./04_agent_policy_same_mechanism.livemd) applies the same method to structured agent policies.

The shorter notebooks in `priv/livebooks/` are stage scenarios. They optimise for a predictable live demonstration. These optimise for understanding.

## Running them

For the container runtime, run `make notebooks` from the clone. Open
<http://localhost:8080>, then open a file under `/data/goatmire/notebooks/` or
`/data/goatmire/priv/livebooks/`. This image includes Maude 3.5.1. Each notebook
uses its own runtime and installs the pinned project into Livebook's cache;
it does not attach to the stage application's node. Run the setup cell during
rehearsal because dependency download and compilation need network access.

For a local Livebook runtime, first run `mise install`, `mise exec -- mix deps.get`,
and `mise exec -- mix maude.install --version 3.5.1` in the clone. Open the notebook
from that directory. If your Livebook copies it elsewhere, set
`LIVEBOOK_GOATMIRE_DIR` to the clone's absolute path in the runtime environment.
`MAUDE_PATH` can point to a separately installed interpreter.

Downloading a `.livemd` file alone does not include this project. The setup cell
reports a missing clone or interpreter before attempting to start the application.
The embedded `/talk` notebook pane uses the already running stage application.

No notebook requires physical hardware. The interpreter is real; the fleet is simulated; every clean verdict is explicitly limited to the detector's model.
