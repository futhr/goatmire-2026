# Talk manuscript — natural 30-minute cut

This is the spoken reference for the Goatmire 2026 talk that opens as **“Formal Verification”** (programme title: “Zero Alert Storms: Formal Verification for IoT Automation”). It follows the 31-slide stage deck at `/talk`, and the private iPad notes view shows it slide by slide.

This manuscript is a safety net, not a text to memorize word for word. Learn the seven-beat spine and each slide's first sentence in [`memorize.md`](./memorize.md); keep the complete text available for recovery. Bold marks the cue words; the iPad shows them in bold. Stage directions are in italics and are not spoken.

Protect these lines:

> A bad answer, a good answer, and no answer are three different things.

> Maude made the decision. The language model explained what the system observed.

> Formal methods strengthen narrow claims. They cannot prove broad ones.

The order matches [`slides/deck.md`](./slides/deck.md) and the live presenter. Start times below are the cumulative budgets from `priv/talk/timings.exs`, which also drive the presenter clock's drift warning. This cut speaks longer than the budgets assumed: if a timed run lands behind, trim the optional asides (the jokes on slides 5, 10, 12, 13 and 19) before touching a protected line, or rebalance the budgets. The presenter timer starts automatically on leaving the holding slide; for a full-talk rehearsal timer, call `Goatmire.Talk.Clock.start_talk/0` with the opening line.

---

## 1 · Formal Verification — 00:00

*(Let the room read. Look up. Two beats.)*

This talk is about one kind of bug, where **every part works** but the system still does the wrong thing.

Picture two automation rules. Two different people wrote them, and each rule makes sense on its own. Both pass their tests. Then you compose both rules, and they **fight over the same device**.

Tests only check the cases you thought of. So before we run anything, I want to ask: **can these rules fight?**

Formal verification can answer that, if we **keep the question small**.

*(Change slide. Pause 2–3 seconds.)*

---

## 2 · Index — 00:40

*(Let the room read the index. Two beats.)*

Five chapters, about thirty minutes.

*(Change slide.)*

---

## 3 · Both apps were reasonable — 00:55

This example comes from a smart-home research paper called **SOTERIA**. They looked at what happens when you compose several apps. Two of them, O3 and O4, react to the same event: a contact sensor opens. And they set the same switch to **different values**.

One wants the switch on. The other wants it off.

On its own, **each rule is reasonable**.

To be clear, this is **not a real incident**, and I'm not claiming this code prevented anything. I rebuilt the same rule shape in a **controlled simulation**.

The paper gives us the conflict. The simulator gives us a safe place to let it get noisy.

*(Change slide.)*

---

## 4 · Both rules are reasonable — 01:45

This is what makes these bugs annoying.

Review O3: contact opens, turn the switch on. Fine. Review O4: contact opens, turn the switch off. Also easy to understand.

An isolated test can confirm that both applications do exactly what their authors asked. **Both tests can pass.**

The disagreement only appears when we **compose them together**.

That gap between **local correctness and composed behaviour** is where today's talk lives.

*(Change slide.)*

---

## 5 · The loop nobody designed — 02:20

**Nobody designed** the combined behaviour on this slide.

*(Point to the quote.)*

**You review one change. The system runs all of them together.**

One thing to be clear about. The paper does not show a loop or an alert storm. It shows two rules writing **different values to the same switch**. That's all.

The storm comes later, and that part we make ourselves. In the warehouse simulator, I **activate a test set of conflicting rules** again and again, so we can measure what happens.

The important point is the irony. Nobody has to write a function called `create_distributed_mess()`. We are perfectly capable of getting there by **composing reasonable things**.

*(Let that sit. Change slide.)*

---

## 6 · Why wait until the rule runs? — 02:55

These two rules already disagree before a device moves, before an alert fires, and before either rule is **active**.

**Runtime monitoring still matters.** Sensors fail, networks lie, and hardware does surprising things.

But this conflict is **already sitting in the rule set**.

So if we can see it before the rule is activated, **why wait for the alerts** to tell us?

The check belongs in a boring place: **between "submit this rule" and "let this rule run."**

That's the key idea: **move the check left**, to the moment someone creates the rule.

*(Change slide.)*

---

## 7 · The gate — 03:25

*(Let the slide sit for a beat.)*

So that's the problem. Now the question we can actually answer, and how the check lives inside the app.

*(Change slide.)*

---

## 8 · Tests and checks answer different questions — 03:35

Why not just write more tests?

**Absolutely write more tests.**

Tests are essential. Property-based tests are excellent. They run the code and show us what happened in the cases we picked, or the cases the tool generated.

Formal checking asks **a different question**. It reads a model of the rules before they run, and asks whether a bad interaction is possible, for the kinds of interaction the model knows about.

That does not prove the whole system is safe. It is a smaller claim.

And the smaller claim is exactly why **the answer can be stronger**.

We are not asking Maude to understand the universe. We just ask it **one specific question**, and we are very clear about what that question is.

*(Change slide.)*

---

## 9 · Four pieces — 04:25

Maude looks unfamiliar at first. But from here on, you only need **four words**.

**Sorts** describe types. **Operators** construct terms or name functions. **Equations** simplify terms. **Rewrite rules** describe possible state transitions.

For an Elixir developer, equations are not a million miles from pattern-matched simplification, while rewrite rules feel like state-machine transitions.

That distinction matters because different Maude commands answer different questions.

*(Change slide.)*

---

## 10 · Reduce is not search — 05:10

`reduce` is not `search`.

Reduce simplifies a term using equations. The first line on screen: toggle twice, and you are back at `on`.

Search explores transitions looking for a reachable state.

If search returns a path, that path is useful: **it is a witness**. It tells us how we got there.

But if a bounded search does not find a witness, that is **not an unbounded proof of safety**.

That distinction is important enough that the surrounding code preserves `unverified` instead of pretending uncertainty means success.

The rule check in this demo uses **reduce, not search**. It runs equations over a finite set of validated rules.

We are not feeding the whole physical world into an open-ended search, and hoping my laptop finds the answer before the coffee break.

We ask **the narrow question** we actually modeled.

*(Change slide.)*

---

## 11 · Four conflict categories — 06:15

This checker knows **four categories** of conflict. A category is one kind of conflict it can spot between two rules, and these four are the only things it looks for.

*(Point to each panel.)*

**Opposite writes**: two rules set the same device to opposite values. That is our switch, on and off.

**Opposite effects**: two rules have opposite effects on the same environment, like temperature or noise. One rule opens a window to cool the room, another closes it to keep the noise out.

**Chain reaction**: one rule's action triggers another rule.

**State and environment chain**: the same thing, but the chain runs through the environment. The AC goes on, a window closes, CO2 rises, the window opens again, and now it fights the AC.

You do not need to memorize them.

**Remember the boundary**: if a problem is not one of these four categories, this checker **does not see it**.

That sounds obvious. It is also easy to forget once the word formal appears on a slide.

*(Change slide.)*

---

## 12 · A narrow claim can be strong — 07:05

**What does a clean result mean?**

It means this check completed, on these validated rules, and found none of the four categories this model knows.

**It does not mean the whole system is safe.**

Nothing here proves a sensor is mounted correctly, a message cannot arrive late, authorization is correct, or that we remembered every hazard.

That is a narrow claim. It is less impressive on LinkedIn.

It is also **one I can defend**.

*(Change slide.)*

---

## 13 · Maude as an ordinary supervised dependency — 07:50

Inside this Elixir application, Maude is not a separate service running as a **sidecar**.

It is an **ordinary supervised dependency**.

A worker pool owns separate Maude processes. If one dies, **supervision can restart it**. The application gets a normal tagged result.

Formal checking can therefore live inside the **same failure-handling discipline** as the rest of the application.

The maths can be unusual. The process lifecycle does not have to be.

*(Change slide.)*

---

## 14 · Verify the term the runtime executes — 08:35

If you remember one design decision from this talk, **make it this one**.

The rule is this one Elixir map on screen. The **same map** goes to two places: the checker reads it, and the runtime runs it.

The alternative is to write the Maude model by hand, next to the code. Now you have two versions of every rule, and over time **they drift apart**.

Then you have proven something very precise about a rule you are **not actually running**.

One shared map does not remove every risk. There is still a small piece of code that turns the map into a Maude term. But that piece is small, and **small pieces are easy to test**.

*(Change slide.)*

---

## 15 · Never turn “no answer” into “yes” — 09:25

The gate has **three answers**. Not two.

`clean`. `conflicts`. And `unverified`.

Clean means the check completed and found no represented conflict. Conflicts means it found a concrete problem and can name the rules. Unverified means it could not answer: Maude unavailable, rejected input, timeout, and so on.

**A bad answer, a good answer, and no answer are three different things.**

For this demo, if the checker cannot answer, the rule is **not activated**.

That fail-closed behaviour is not a theorem from Maude. It is **application policy**, and I chose it explicitly.

*(Pause. Change slide.)*

---

## 16 · Every arrow deserves a test — 10:30

Formal checking does not make the plumbing **trustworthy by association**.

The Elixir rule becomes an encoded term. Maude produces output. The application parses that into a typed answer. Another piece of code turns the answer into **activate or stop**.

**Every arrow deserves a test.**

Validate input. Test the encoder. Test the parser. Test the activation step with all three answers: clean, conflicts, and unverified.

Otherwise the formal core can be perfectly correct while **the glue quietly lies**.

*(Change slide.)*

---

## 17 · Partition on interaction edges — 11:10

Comparing every rule with every other rule is not particularly clever.

So the partitioner groups rules by how they can **interact**: rules that touch the same device, rules that write to the same property, and rules where one writes a property that another one triggers on.

Grouping only by device would miss **cross-device interactions**.

The partitioner deliberately **over-groups** when uncertain. That can cost comparisons. It must not optimize away an interaction the model could have found.

*(Reveal the code pane and run it. Point to the counts and read the actual values.)*

Those are **today's run counts**, not a universal scaling claim.

*(Change slide. Prepare Rules demo.)*

---

## 18 · Live: IoT rules — 12:10

*(Let the slide sit for a beat.)*

Enough slides. Let's watch it happen.

*(Change slide. Prepare Rules demo.)*

---

## 19 · Catch the conflict before the rule exists — 12:20

*(Reveal Rules pane. Pause while switching windows.)*

I deploy the switch-on rule first.

*(Run scripted step. Let UI settle.)*

Nothing dramatic.

Now I load the switch-off rule as the candidate. Instead of creating it directly, I press **Check and create**.

*(Run. Pause for result. Point instead of talking over the UI.)*

There.

The answer is `state_conflict`, and it **names both rules**.

Notice what the checker did not do. It did not decide that on is morally superior to off. It does not know which application has the better product manager.

It knows these rules disagree under the model I gave it.

So the gate stops the new combination and **leaves the policy decision to a person**.

The conflicting pair **never exists in the active rule set**.

*(Allow 5–10 seconds for room to read. Return to deck.)*

---

## 20 · Run the same shift change twice — 13:50

Now I want to **make the difference visible**.

*(Reveal Warehouse pane. Pause.)*

We run the same simulated shift change twice.

First: **observe mode**. The checker records the conflict, but the rules still get activated, so we can see what that does.

*(Run Observe. Each run takes about 30 seconds.)*

**Watch the alert counter.**

*(Then stay quiet. Let counters settle.)*

These numbers come from this simulator, on this laptop, with these settings. They are **not a real incident**, and not a benchmark.

Same fleet, same settings, this time **enforce mode**. The two runs are never identical, there is randomness in the readings and the scheduling. So don't read the exact numbers. **Read the difference.**

*(Run Enforce. Do not press Clear: each run resets the engine itself.)*

Same counter. Watch it again.

*(Pause. Point to withheld rules and alert count.)*

The broker did not become faster. The load did not magically disappear.

The difference happened earlier: the conflicting rules **were never activated**.

That is the whole point. **Move the decision left**, before the rules ever run.

*(Let room inspect. Return to deck.)*

---

## 21 · Ask the running system why — 17:05

We have counters. Somebody still has to interpret them.

*(Reveal Diagnostics.)*

The diagnostic tool receives a **small, read-only snapshot**. We ask why alerts rose, what formal answer came with the run, and what to inspect next.

*(Submit. Wait. Do not narrate spinner.)*

Look at the split.

**Observations point back to structured fields**. Suggestions are **labelled inference**.

Most importantly: **Maude made the decision. The language model explained what the system observed.**

The model **cannot activate the rule**. It cannot talk `conflicts` into becoming `clean`.

That separation is more interesting to me than putting an LLM in front of every button.

*(Return to slides.)*

---

## 22 · Live: AI policy — 18:45

*(Let the slide sit for a beat.)*

So far, people wrote the rules. Now we let a model write them. **Same gate, same question.**

*(Change slide.)*

---

## 23 · An LLM may propose policy; it should not judge itself — 18:55

The same boundary applies when **the language model is the author**.

Say an LLM proposes a policy, or a tool call. Fine.

*(Point to the code.)*

On screen: a high-impact tool called `dose`, tagged as running in the EU.

Take that structured output, validate it, and hand it to a **separate, deterministic check**. Same policy in, same answer out, every time.

We check the policy the model wrote. We are **not verifying the model itself**.

*(Change slide.)*

---

## 24 · Exactly seven categories — 19:40

The AI-policy detector has **exactly seven categories** of conflict. They are on the slide, so I will not read them all.

The number is useful mostly because it tells us **what we did not check**.

Cost limits are not secretly category eight. Which provider you call is not secretly category nine.

*(Point to the quote.)*

If a property is not in the model, this detector did not check it.

The next demo uses two of them: **approval-gate bypass and sovereignty violation**. Nothing more heroic than that.

*(Change slide.)*

---

## 25 · The model suggests. The gate decides. — 20:25

When the check finds a conflict, it comes back with a **type**. Approval gate bypass, for example. That gives the model **something concrete to fix**.

There is an optional scenario in the repo where the model writes the rules. Ask it for structured rules, validate them, run the check, and feed any conflict back for a second try.

But there is **no magic second try**.

The revised policy can still be wrong. Generation can fail. The provider can be down.

So the scenario **keeps every completed result**, instead of rewriting history until the screen turns green.

If the model is unavailable, show that failure and continue to the deterministic check.

*(Point to the quote.)*

**The model does not judge its own work.**

*(Change slide. Prepare Notebook demo.)*

---

## 26 · Approval missing → clean revision → wrong jurisdiction — 21:05

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

## 27 · Takeaways — 23:45

*(Let the slide sit for a beat.)*

That was the last demo. Let me pull this together.

*(Change slide.)*

---

## 28 · Maude is not the only answer — 23:55

Maude is **not the answer to every formal-methods problem**.

Pick the tool that makes your property **easiest to state**.

*(Point down the rows.)*

Maude, when the system is terms and transitions, like the rules today. TLA+, for distributed protocols that must never reach a bad state. Alloy, for data models and their constraints. Z3, for constraint problems. Types and model checking, for protocol conformance.

The tools you already use here answer other questions again. Property-based tests ask whether a generated run fails. Concuerror asks whether some ordering of your processes breaks. **Different questions, so keep using them.**

Tool choice should **follow the property**, not loyalty to the tool I happened to put in a conference talk.

*(Change slide.)*

---

## 29 · Keep the claim attached to its evidence — 24:40

Before taking this toward production, **keep the claim attached to its evidence**.

Validate inputs. Test every translation step. Bound checking work. Recover uncertain workers. Record which model, interpreter, validated input, verdict and activation decision belong together.

Those are engineering requirements. They are **not a claim that this demo is production proven**.

Its state is in memory. Its broker is a trusted local support service. **Its fleet is simulated.**

An audit artifact helps review what happened. It does not automatically satisfy a regulation, and it definitely does not prove a property we **never modeled**.

*(Change slide.)*

---

## 30 · Decision model + Maude — 25:30

*(If time permits.)*

A fair question, especially now that Jev is out: why not a **decision model instead of Maude?**

I would use both. A decision model, Jev or a classifier you trained yourself, **handles ambiguity**: what is likely, and how likely? **Maude does the explicit check**: is this allowed by the model?

*(Point to the quote.)*

That gives you flexible judgement inside explicit boundaries. The decision model can classify uncertain input, Maude can stop a conflict, and the application can act or escalate. And whatever the confidence says, it **never turns a conflict into clean**.

**The decision model asks what is likely. Maude asks what the model allows.**

*(Change to final slide.)*

---

## 31 · Formal methods strengthen narrow claims — 26:10

The code and notebooks from today are on GitHub if you want to **try this, or break it**.

So, what I'd like you to take with you. You saw **rules fight** when we let them run, and you saw the gate hold them back before they could. When the checker can't answer, treat that as **its own answer, never as a yes**. And check **the rule you actually run**, with tests on every step in between.

*(Point to the quote.)*

**Formal methods strengthen narrow claims.**

**They cannot prove broad ones.**

Thank you.

*(Stop. Let the ending stand. Do not rush to fill the silence.)*

---

## Hard-cut map

- On slides 9–11, keep the four-word vocabulary, the reduce/search distinction, and the model boundary; omit elaboration.
- On slide 17, name the three interaction edges and read only the current partition count.
- On slide 21, protect the observation/inference sentence and the Maude/LLM boundary.
- If LIVE 04 (slide 26) would start after 23:30, skip the live notebook and say its three outcomes in one sentence each.
- Slide 30 is the first clean cut when late. If used, keep it to: the decision model asks what is likely; Maude asks what the model allows; they can coexist.
- The chapter dividers (7, 18, 22, 27) are ten seconds each: say the bridge and move on.
- Begin the close (31) no later than 26:00. Keep the takeaways and the final quote.

## Delivery

- Protect real silence while UI actions execute; point at what to watch instead of narrating the wait.
- Read current counters and results; do not memorize benchmark-looking values.
- No introduction, CV, or self-promotion anywhere. Problem first.
- Keep the GitHub mention shallow: somewhere to try or break the ideas. Not another technical section.
