# Talk manuscript — natural 30-minute cut

This is the spoken reference for the Goatmire 2026 talk that opens as **“Formal Verification”** (programme title: “Zero Alert Storms: Formal Verification for IoT Automation”). It follows the 26-slide stage deck at `/talk`, and the private iPad notes view shows it slide by slide.

This manuscript is a safety net, not a text to memorize word for word. Learn the seven-beat spine and each slide's first sentence in [`memorize.md`](./memorize.md); keep the complete text available for recovery. Bold marks the cue words; the iPad shows them in bold. Stage directions are in italics and are not spoken.

Protect these lines:

> A bad answer, a good answer, and no answer are three different things.

> Maude made the decision. The language model explained what the system observed.

> Formal methods make a narrow claim strong. They do not make a broad claim true.

The order matches [`slides/deck.md`](./slides/deck.md) and the live presenter. Start times below are the cumulative budgets from `priv/talk/timings.exs`, which also drive the presenter clock's drift warning. This cut speaks longer than the budgets assumed: if a timed run lands behind, trim the optional asides (the jokes on slides 4, 8, 10, 11 and 16) before touching a protected line, or rebalance the budgets. The presenter timer starts automatically on leaving the holding slide; for a full-talk rehearsal timer, call `Goatmire.Talk.Clock.start_talk/0` with the opening line.

---

## 1 · Formal Verification — 00:00

*(Let the room read. Look up. Two beats.)*

This talk is about bugs where **every part works** and the system still does the wrong thing.

Take two automation rules. Each was written by someone sensible, and each passes its own tests. Install them together and they **fight over the same device**.

Tests show what happened in the runs we tried. I want to ask a different question, before anything runs: **can these rules fight?**

Formal verification can answer that, as long as **the question stays small**.

*(Change slide. Pause 2–3 seconds.)*

---

## 2 · Both apps were reasonable — 00:40

This comes from the published smart-home study **SOTERIA**. In its multi-app evaluation, O3 and O4 react to the same contact-open event with **conflicting switch values**.

One wants the switch on. The other wants it off.

**Neither rule is absurd** when read alone.

As the slide says, this repository reproduces the rule shape in a **controlled simulation**. It is **not a real incident**, and this code did not prevent their published result.

The published pattern gives us the conflict. Our simulator gives us somewhere safe to make that conflict noisy.

*(Change slide.)*

---

## 3 · Both rules are reasonable — 01:30

This is what makes these bugs annoying.

Review O3: contact opens, turn the switch on. Fine. Review O4: contact opens, turn the switch off. Also easy to understand.

An isolated test can confirm that both applications do exactly what their authors asked. **Both tests can pass.**

The disagreement only appears when we **install them together**.

That gap between **local correctness and composed behaviour** is where today's talk lives.

*(Change slide.)*

---

## 4 · The loop nobody designed — 02:05

**Nobody designed** the combined behaviour on this slide.

*(Point to the quote.)*

**You review one change. The system runs all of them together.**

One caveat. The published O3/O4 example does not prove an alert loop. It establishes **conflicting writes**.

Later I deliberately activate a **synthetic conflicting set** repeatedly in the warehouse simulator so we can measure that separate repeated effect.

The important point is the irony. Nobody has to write a function called `create_distributed_mess()`. We are perfectly capable of getting there by **composing sensible things**.

*(Let that sit. Change slide.)*

---

## 5 · Why wait until after deployment? — 02:40

The relationship between these rules exists before a device moves, before an alert fires, and before deployment.

**Runtime monitoring still matters.** Sensors fail, networks lie, hardware does surprising things.

But this disagreement is **already sitting in the rule set**.

So if we can see it before deployment, **why wait for telemetry** to discover it afterwards?

The check belongs in a boring place: **between "submit this rule" and "let this rule run."**

That is the architectural move.

*(Change slide.)*

---

## 6 · Tests and checks answer different questions — 03:10

Why not just write more tests?

**Absolutely write more tests.**

Tests are essential. Property-based tests are excellent. They execute software and show us what happened in selected or generated cases.

Formal checking asks **a different question**. It reads a model of the rules before they run and asks whether a represented bad interaction is possible.

That is not proving the entire installation safe. It is a smaller claim.

And the smaller claim is exactly why **the answer can be stronger**.

We are not asking Maude to understand the universe. We are asking it **a specific question** we bothered to define.

*(Change slide.)*

---

## 7 · Four pieces — 04:00

Maude looks intimidating at first. For this talk you need about **four words**.

**Sorts** describe types. **Operators** construct terms or name functions. **Equations** simplify terms. **Rewrite rules** describe possible state transitions.

For an Elixir developer, equations are not a million miles from pattern-matched simplification, while rewrite rules feel like state-machine transitions.

That distinction matters because different Maude commands answer different questions.

*(Change slide.)*

---

## 8 · Reduce is not search — 04:45

`reduce` is not `search`.

Reduce simplifies a term using equations. The first line on screen: toggle twice, and you are back at `on`.

Search explores transitions looking for a reachable state.

If search returns a path, that path is useful: **it is a witness**. It tells us how we got there.

But if a bounded search does not find a witness, that is **not an unbounded proof of safety**.

That distinction is important enough that the surrounding code preserves `unverified` instead of pretending uncertainty means success.

Today's IoT gate deliberately uses a finite validated **equational detector**. We are not throwing the entire physical world at an unrestricted state-space search and hoping my laptop achieves enlightenment before the coffee break.

We ask **the narrow question** we actually modeled.

*(Change slide.)*

---

## 9 · Four conflict categories — 05:50

This demo has **four categories**.

Two rules can write opposite values. They can push the same environment in opposite directions. One rule can trigger another. Or that chain can cross between device state and environment.

You do not need to memorize them.

**Remember the boundary**: if a problem is not represented in what this checker understands, this checker **does not see it**.

That sounds disappointingly obvious. It is also easy to forget once the word formal appears on a slide.

*(Change slide.)*

---

## 10 · A narrow claim can be strong — 06:40

**What does a clean result mean?**

It means this check completed, on these validated rules, and found none of the four conflict types represented by this model.

**It does not mean the entire installation is safe.**

Nothing here proves a sensor is mounted correctly, a message cannot arrive late, authorization is correct, or that we remembered every hazard.

That narrower sentence is less impressive on LinkedIn.

It is also **one I can defend**.

*(Change slide.)*

---

## 11 · Maude as an ordinary supervised dependency — 07:25

Inside this Elixir application, Maude is not a sacred process living on a university workstation somewhere.

It is an **ordinary supervised dependency**.

A worker pool owns separate Maude processes. If one dies, **supervision can restart it**. The application gets a normal tagged result.

Formal checking can therefore live inside the **same failure-handling discipline** as the rest of the application.

The maths can be unusual. The process lifecycle does not have to be.

*(Change slide.)*

---

## 12 · Verify the term the runtime executes — 08:10

This is probably the implementation decision **I care about most**.

The map on screen is the rule. The checker reads that representation. The runtime executes **that same representation**.

If I verify a second handwritten copy, **the copy can drift**.

Then I get the wonderful situation where I checked something very precise about **software I am not actually running**.

Sharing the representation does not remove every translation risk. It makes the boundary smaller, and smaller boundaries are easier to test.

*(Change slide.)*

---

## 13 · Never turn “no answer” into “yes” — 09:00

The gate has **three answers**. Not two.

`clean`. `conflicts`. And `unverified`.

Clean means the check completed and found no represented conflict. Conflicts means it found a concrete problem and can name the rules. Unverified means it could not answer: Maude unavailable, rejected input, timeout, and so on.

**A bad answer, a good answer, and no answer are three different things.**

For this demo an unverified candidate is **not deployed**.

That fail-closed behaviour is not a theorem from Maude. It is **application policy** we chose explicitly.

*(Pause. Change slide.)*

---

## 14 · Every arrow deserves a test — 10:05

Formal checking does not make the plumbing **trustworthy by association**.

The Elixir rule becomes an encoded term. Maude produces output. The application parses that into a typed answer. Another piece of code turns the answer into deploy or stop.

**Every arrow deserves a test.**

Validate input. Test the encoder. Test the parser. Test deployment with clean, conflicts, and unverified.

Otherwise the formal core can be perfectly correct while **the glue quietly lies**.

*(Change slide.)*

---

## 15 · Partition on interaction edges — 10:45

Comparing every rule with every other rule is not particularly clever.

So we partition based on **interaction edges**: rules that share a Thing, write the same action target, or connect a writer to a trigger property.

Grouping only by Thing would miss **cross-Thing interactions**.

The partitioner deliberately **over-groups** when uncertain. That can cost comparisons. It must not optimize away an interaction the model could have found.

*(Reveal the code pane and run it. Point to the counts and read the actual values.)*

Those are **today's run counts**, not a universal scaling claim.

*(Change slide. Prepare Rules demo.)*

---

## 16 · Catch the conflict before the rule exists — 11:45

Okay. **Enough slides.** Let's actually do it.

*(Reveal Rules pane. Pause while switching windows.)*

I deploy the switch-on rule first.

*(Run scripted step. Let UI settle.)*

Nothing dramatic.

Now I load the switch-off rule as the candidate. Instead of creating it directly, I press **Check and create**.

*(Run. Pause for result. Point instead of talking over the UI.)*

There.

The answer is `state_conflict`, and it **names both rules**.

Notice what the checker did not do. It did not decide that on is morally superior to off. It does not know which application has the better product manager.

It knows these rules disagree under the model we gave it.

So the gate stops the new combination and **leaves the policy decision to a person**.

The conflicting pair **never exists in the active rule set**.

*(Allow 5–10 seconds for room to read. Return to deck.)*

---

## 17 · Run the same shift change twice — 13:15

Now I want to **make the difference visible**.

*(Reveal Warehouse pane. Pause.)*

We run the same simulated shift change twice.

First: **observe mode**. The checker records the conflict, but we allow activation so we can see the symptom.

*(Run Observe. Each run takes about 30 seconds.)*

**Watch the alert counter.**

*(Then stay quiet. Let counters settle.)*

Those are measurements from this simulator, on this laptop, with these settings. They are **not a customer incident** and not a universal benchmark.

Same fleet, tick and shift settings, this time **enforce mode**. Scheduling and random readings can still differ between runs; this is not cycle-accurate comparison.

*(Run Enforce. Do not press Clear: each run resets the engine itself.)*

Same counter. Watch it again.

*(Pause. Point to withheld rules and alert count.)*

The broker did not become faster. The load did not magically disappear.

The difference happened earlier: the conflicting rules **never reached activation**.

That is what I care about — **moving the decision left**, before runtime experiences the disagreement.

*(Let room inspect. Return to deck.)*

---

## 18 · Ask the running system why — 16:30

We have counters. Somebody still has to interpret them.

*(Reveal Diagnostics. Point to provider.)*

The diagnostic tool receives a **small, read-only snapshot**. We ask why alerts rose, what formal answer came with the run, and what to inspect next.

*(Submit. Wait. Do not narrate spinner.)*

Look at the split.

**Observations point back to structured fields**. Suggestions are **labelled inference**. The provider name tells us whether Codex or local Ollama produced the explanation.

With Ollama the snapshot stays on this laptop. With Codex that limited context goes to the signed-in service.

Most importantly: **Maude made the decision. The language model explained what the system observed.**

The model **cannot deploy the candidate**. It cannot talk `conflicts` into becoming `clean`.

That separation is more interesting to me than putting an LLM in front of every button.

*(Return to slides.)*

---

## 19 · An LLM may propose policy; it should not judge itself — 18:10

The same boundary applies when **the language model is the author**.

Suppose an LLM proposes a policy or structured tool invocation. Fine.

*(Point to the code.)*

On screen: a high-impact tool called `dose`, in the EU jurisdiction.

Take the structured result, validate it, and give it to a **separate deterministic policy model**.

We are checking the emitted policy. We are **not formally verifying the language model**.

*(Change slide.)*

---

## 20 · Exactly seven categories — 18:55

The AI-policy detector has **exactly seven categories**. They are on the slide, so I will not read them all.

The number is useful mostly because it tells us **what we did not check**.

Budget ceilings are not secretly category eight. Provider routing is not secretly category nine.

If a property is not in the model, this detector did not check it.

The next demo uses two of them: **approval-gate bypass and sovereignty violation**. Nothing more heroic than that.

*(Change slide.)*

---

## 21 · Put a deterministic gate around a probabilistic author — 19:40

A typed conflict gives a probabilistic author **something concrete to revise**.

The optional generation scenario can ask the configured model for structured rules, validate them, check them, and feed a conflict back for another attempt.

But there is **no magic second-turn guarantee**.

The revised policy can still be wrong. Generation can fail. The provider can be unavailable.

So we **preserve each completed result** instead of rewriting history until the screen becomes green.

If the model is unavailable, show that failure and continue to the deterministic check.

*(Point to the quote.)*

**The author does not grade its own work.**

*(Change slide. Prepare Notebook demo.)*

---

## 22 · Approval missing → clean revision → wrong jurisdiction — 20:20

*(Reveal Notebook pane. Run Initialize, Check interpreter and Define policy while speaking. They are setup cells.)*

This final demo is **deliberately boring**.

No fleet. No broker. No language model. No network.

First: a high-impact tool **without approval**.

*(Run Missing approval. Pause.)*

`approval_gate_bypass`.

Now **add required approval**.

*(Run Approval added. Pause.)*

For the conflict categories this checker was asked to inspect: clean.

Finally, send the action to **the US** while allowed regions are the EU and Switzerland.

*(Run Wrong region. Pause.)*

`sovereignty_violation`.

**Three structured inputs. Three readable answers.**

The generated Maude command stays attached to the policy we just inspected.

Nothing had to persuade itself that it was correct.

*(Return to slides.)*

---

## 23 · Maude is not the only answer — 23:00

Maude is **not the answer to every formal-methods problem**.

Choose the tool that makes your property **easiest to state precisely**.

Maude fits algebraic terms and concurrent transitions. TLA+ or PlusCal can make temporal distributed behaviour clearer. Alloy is excellent for bounded relational structures. SMT solvers such as Z3 fit constraint problems.

Types and protocol models solve other pieces.

Tool choice should **follow the property**, not loyalty to the tool I happened to put in a conference talk.

*(Change slide.)*

---

## 24 · Keep the claim attached to its evidence — 23:45

Before taking this toward production, **keep the claim attached to its evidence**.

Validate inputs. Test every translation step. Bound checking work. Recover uncertain workers. Record which model, interpreter, validated input, verdict and activation decision belong together.

Those are engineering requirements. They are **not a claim that this demo is production proven**.

Its state is in memory. Its broker is a trusted local support service. **Its fleet is simulated.**

An audit artifact helps review what happened. It does not automatically satisfy a regulation, and it definitely does not prove a property we **never modeled**.

*(Change slide.)*

---

## 25 · Why not Jev instead? — 24:35

At this point there is a **very new question** I expect people to ask: why not use **Jev instead of Maude?**

Jev is TypeSafe AI's first public **System One Model**. It gives up string generation: program state and typed questions in, **typed probabilistic decisions with confidence** out.

Architecturally, that is surprisingly close to where this gate sits. Software asks a question and gets a machine-readable answer. But the **contract is different**.

Jev is for judgement under uncertainty: does this trace look suspicious, which category fits, how confident are we? The application thresholds that probability or escalates uncertainty.

This Maude detector is for properties we have **written down exactly**. Given the same validated term and the same equational model, the encoded predicate has a fixed result. It understands less, but its answer is **not a probability**.

So I would not choose **Jev or Maude**. Use Jev where hard rules are brittle; use Maude where an invariant is important enough to state exactly. They can sit in the same pipeline.

**Jev gives a probability about an ambiguous question. Maude gives the result of an explicit predicate.**

*(Change to final slide.)*

---

## 26 · Formal methods make a narrow claim strong — 25:55

The code and notebooks from today are on GitHub if you want to **try this, or break it**.

What I'm working on now is **Wotex**. It's **not finished**. It's an attempt at **one unified protocol** for the Web of Things. Others have tried, and nobody has succeeded yet. Maude is a smaller part of it. It sits in the testing and execution logic.

So, what I'd like you to take with you. You saw **rules fight** when we let them run, and you saw the gate hold them back before they could. When the checker can't answer, treat that as **its own answer, never as a yes**. And check **the rule you actually run**, with tests on every step in between.

*(Point to the quote.)*

**Formal methods make a narrow claim strong.**

**They do not make a broad claim true.**

Thank you.

*(Stop. Let the ending stand. Do not rush to fill the silence.)*

---

## Hard-cut map

- On slides 7–9, keep the four-word vocabulary, the reduce/search distinction, and the model boundary; omit elaboration.
- On slide 15, name the three interaction edges and read only the current partition count.
- On slide 18, protect the observation/inference sentence and the Maude/LLM boundary.
- If LIVE 04 (slide 22) would start after 23:30, skip the live notebook and say its three outcomes in one sentence each.
- On slide 25, if late, keep only the distinction: Jev returns a probabilistic decision; this Maude detector evaluates an explicit predicate. They can coexist.
- Begin the close (26) no later than 26:00. Keep the takeaways and the final quote.

## Delivery

- Protect real silence while UI actions execute; point at what to watch instead of narrating the wait.
- Read current counters and results; do not memorize benchmark-looking values.
- No introduction, CV, or self-promotion anywhere. Problem first.
- Keep the GitHub and Wotex mentions shallow: somewhere to try or break the ideas, and what I'm working on. Not another technical section.
