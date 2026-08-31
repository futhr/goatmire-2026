# Talk manuscript — plain-language 30-minute cut

This is the spoken reference for **“Zero Alert Storms: Formal Verification for IoT Automation.”** It follows the 18-slide stage deck at `/talk`.

The target is to finish the prepared talk in about 25–26 minutes. The remaining time is for silence while the room reads, a slow live action, recovery, or questions. This manuscript is a safety net, not a text to memorize word for word. Learn the seven-beat spine and each slide's first sentence; keep the complete text available for recovery.

Protect these lines:

> A bad answer, a good answer, and no answer are three different things.

> Maude made the decision. The language model explained what the system observed.

Stage directions are in italics and are not spoken.

---

## 1 · Zero Alert Storms — 00:00

*(Let the room read the title. Look up.)*

Hi. I’m Tobias.

Today we are going to make two reasonable automation rules fight each other. Then we will stop the same conflict before either rule can run.

I have worked in software since 1998 and in IoT for eleven years. That has taught me one simple lesson: “be more careful” is not a deployment control.

---

## 2 · Two reasonable rules disagree — 00:45

This example comes from a published smart-home study called SOTERIA.

Two apps react to the same event: a contact sensor opens. One app turns a switch on. The other turns the same switch off.

Neither rule looks foolish by itself. The problem appears when both rules live in the same system.

This repository reproduces that rule pattern in a controlled simulation. It is not a story about a real damaged home, and I am not claiming this code prevented the published result.

---

## 3 · The system runs the set — 02:15

Look at the two values: on and off. That is the whole bug.

A code review normally looks at one change. The running system does not run one change; it runs every active rule together.

That is the idea behind the word *composition*: things that look reasonable alone can become unreasonable together.

---

## 4 · Why wait until after deployment? — 03:10

The relationship between these rules exists before a device moves and before an alert fires.

Runtime monitoring still matters. But if we can see this conflict before deployment, why wait for telemetry to discover it afterwards?

The check belongs between “submit this rule” and “let this rule run.”

---

## 5 · Tests and checks answer different questions — 03:45

Why not solve this with more tests?

Tests are essential. They run the software and show what happened in selected cases. Property-based tests try many generated cases and often find surprises.

The formal checker asks a different question. It reads the rules before they run and asks: can these rules fight in one of the ways we defined?

That question is smaller than “is the whole system safe?” The smaller question is exactly why the answer can be stronger.

---

## 6 · Maude turns rules into an answer — 05:05

Maude is the tool doing that check.

We give it validated rules and precise definitions of a conflict. It compares the rules with those definitions. If it finds a problem, it returns the concrete rules involved.

You do not need to learn the Maude language for this talk. The important part is the boundary: Maude checks what we described. It does not know about every physical hazard, permission, timing issue, or missing requirement.

---

## 7 · Four ways rules can fight — 06:25

This demo checks four kinds of interaction.

Two rules can write opposite values. They can push the same environment in opposite directions. One rule can trigger another. Or that chain can cross between device state and the environment.

You do not need to remember the list. Remember the limit: if a problem is not represented here, this checker does not see it.

---

## 8 · A narrow answer is still useful — 07:30

So let’s say exactly what a clean result means.

It means this check completed and found none of these four conflict types in these rules.

It does not mean the whole installation is safe. It says nothing about a sensor mounted backwards, a late message, missing authorization, or a hazard we forgot to model.

That narrower sentence is less dramatic. It is also one I can defend.

---

## 9 · Maude runs as a supervised worker — 08:35

Inside this Elixir application, Maude behaves like an ordinary dependency.

A supervised worker pool owns separate Maude processes. If one worker dies, its supervisor restarts it. The application call returns a normal tagged result.

The operational point is simple: formal checking does not have to live in a separate academic universe. It can sit inside the same failure-handling structure as the rest of the application.

---

## 10 · Check the same rule you run — 09:35

This is the implementation choice I care about most.

The map on screen is the rule. The checker reads that map, and the runtime executes that same map.

If we checked a second handwritten copy, the copy could drift away from reality. Then we could prove something precise about the wrong rule.

Sharing the representation does not remove every translation risk, but it makes the boundary smaller and easier to test.

---

## 11 · Never turn “no answer” into “yes” — 10:45

The gate keeps three answers, not two.

`clean` means the check completed and found no conflict represented by this model.

`conflicts` means it found a concrete problem and names the rules involved.

`unverified` means it could not answer—for example because Maude was unavailable, the input was rejected, or the command timed out.

A bad answer, a good answer, and no answer are three different things.

This demo fails closed: an unverified rule is not deployed. That is an application policy we chose explicitly.

---

## 12 · Test every translation step — 12:05

Formal checking is only as trustworthy as the path around it.

The Elixir rule becomes an encoded rule. Maude produces text. The application turns that text into a typed answer and then into “deploy” or “stop.”

Every arrow deserves a test: validate the input, test the encoder, test the parser, and test what deployment does with all three answers.

---

## 13 · LIVE 01 — Catch the conflict — 13:05

*(Reveal the Rules pane.)*

Now we will put the gate in the deployment path.

I’ll deploy the switch-on rule first. Then I’ll load the switch-off rule as the candidate and press “Check and create.”

*(Run the three scripted steps. Point to the answer and rule ids.)*

The answer is `state_conflict`, and it names both rules. The checker does not decide which rule is morally better. It only knows they disagree, so the gate stops the new combination and leaves that decision to a person.

The conflicting pair never exists in the active set.

*(Fallback: `mix goatmire.scenario 1`.)*

---

## 14 · LIVE 02 — Run the same shift twice — 14:45

*(Reveal the Warehouse pane. Use the rehearsed fleet size.)*

Now we will run the same simulated shift change twice.

First is observe mode. The checker records the conflict but allows it to run so we can see the symptom.

*(Run Observe. Pause and read the displayed counters.)*

Those are measurements from this simulator, on this laptop, with the settings on screen. They are not a customer incident or a universal benchmark.

Now we reset and run the same load in enforce mode.

*(Run Enforce. Read the withheld rules and alert count.)*

The load did not disappear, and the broker did not become faster. The difference is earlier: the conflicting rules never reached activation.

The screen keeps the current verdict and counters together, so we can compare evidence from the same staged run.

---

## 15 · LIVE 03 — Ask the running system why — 18:15

*(Reveal Diagnostics. Point to the provider name.)*

We have numbers. Now let’s ask the running system to explain them.

The diagnostic tool receives a small, read-only snapshot. We ask why alerts rose, what formal answer came with the run, and what to inspect next.

*(Submit. Point to cited fields and the observation/inference split.)*

The observations point back to structured fields. Suggestions are labelled as inference. The provider name shows whether Codex or the local Ollama fallback produced the explanation. With Ollama the snapshot stays on this laptop; with Codex that limited context goes to the signed-in service.

Most importantly: Maude made the decision. The language model explained what the system observed. It cannot deploy a rule or change `conflicts` into `clean`.

---

## 16 · AI may suggest; the checker decides — 20:05

The same boundary is useful when an AI writes the first draft of a rule.

An AI can suggest structured automation or policy. We validate that structure and run a separate, predictable check before anything is admitted.

If the checker finds a problem, the author can revise the rule and try again. If the AI is unavailable, the check still works.

The useful distinction is simple: the AI may suggest; the checker decides. The author does not grade its own work.

---

## 17 · LIVE 04 — The policy by hand — 21:35

*(Reveal the Notebook pane.)*

This last demo has no fleet, broker, language model, or network. It is deliberately boring—and therefore a good recovery path.

First, a high-impact tool is used without approval. The checker reports `approval_gate_bypass`.

Then we add approval. The checker finds none of the conflict types it was asked to check.

Finally, we send an action to the US when the allowed regions are the EU and Switzerland. The answer is `sovereignty_violation`.

Three inputs. Three readable answers. The generated Maude command stays attached to the structured policy we just read.

---

## 18 · Close — 24:35

The code, notebooks, and demo are open if you want to try this pattern.

Please take away three things.

First: check rules together before deployment, because reasonable rules can become unreasonable together.

Second: keep `clean`, `conflicts`, and `unverified` separate. Never turn “I could not check” into “yes.”

Third: check the same rule the runtime will execute, and test every translation step around it.

Formal methods make a narrow claim strong. They do not make a broad claim true.

Thank you.

*(Stop. Let the ending stand.)*

---

## Hard-cut map

If the clock is late:

- On slide 7, say only the first and last paragraphs.
- On slide 9, say only: “Maude runs as a supervised worker, like another application dependency.”
- On slide 15, keep the observation/inference sentence and the Maude/LLM boundary; omit provider detail.
- If LIVE 04 would start after 23:30, skip from slide 16 to the close.
- Begin the close no later than 26:00.
