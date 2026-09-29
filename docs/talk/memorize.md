# Learn the talk — seven beats and thirty-one anchors

The full wording lives in [`manuscript.md`](./manuscript.md) and on the private iPad notes view. It is a recovery aid, not a memorization assignment.

Learn only three layers:

1. The seven-beat story below.
2. The first sentence—the anchor—of each slide.
3. The five protected lines at the end of this document.

Everything between an anchor and an exit can be said naturally from the slide. If you blank, read the current iPad block, look back at the room, and continue. Do not apologize.

## The seven-beat story

1. Two reasonable rules can fight when they run together.
2. That conflict exists before the rule is ever activated.
3. A formal checker can answer one small, precise question.
4. The gate must keep `clean`, `conflicts`, and `unverified` separate.
5. Check the same rule the runtime will execute.
6. The live comparison shows the effect of stopping the conflict early.
7. Probabilistic models can judge uncertainty; formal models decide the invariants we explicitly encode.

## Slide anchors

| Slide | Anchor | Exit |
|---:|---|---|
| 1 | Five chapters, about thirty minutes. | Five chapters, about thirty minutes. |
| 2 | This talk is about one kind of bug, where every part works but the system still does the wrong thing. | Formal verification can answer that, if we keep the question small. |
| 3 | This example comes from a smart-home research paper called SOTERIA. They looked at what happens when you compose several apps. Two of them, O3 and O4, react to the same event: a contact sensor opens. And they set the same switch to different values. | The simulator gives us a safe place to let it get noisy. |
| 4 | This is what makes these bugs annoying. | That gap between local correctness and composed behaviour is where today's talk lives. |
| 5 | Nobody designed the combined behaviour on this slide. | We are perfectly capable of getting there by composing reasonable things. |
| 6 | These two rules already disagree before a device moves, before an alert fires, and before either rule is active. | That's the key idea: move the check left, to the moment someone creates the rule. |
| 7 | So that's the problem. Now the question we can actually answer, and how the check lives inside the app. | So that's the problem. Now the question we can actually answer, and how the check lives inside the app. |
| 8 | Why not just write more tests? | We just ask it one specific question, and we are very clear about what that question is. |
| 9 | Maude looks unfamiliar at first. But from here on, you only need four words. | That distinction matters because different Maude commands answer different questions. |
| 10 | reduce is not search. | We ask the narrow question we actually modeled. |
| 11 | This checker knows four categories of conflict. A category is one kind of conflict it can spot between two rules, and these four are the only things it looks for. | It is also easy to forget once the word formal appears on a slide. |
| 12 | What does a clean result mean? | It is also one I can defend. |
| 13 | Inside this Elixir application, Maude is not a separate service running as a sidecar. | The process lifecycle does not have to be. |
| 14 | If you remember one design decision from this talk, make it this one. | But that piece is small, and small pieces are easy to test. |
| 15 | The gate has three answers. Not two. | It is application policy, and I chose it explicitly. |
| 16 | Formal checking does not make the plumbing trustworthy by association. | Otherwise the formal core can be perfectly correct while the glue quietly lies. |
| 17 | Comparing every rule with every other rule is not particularly clever. | Those are today's run counts, not a universal scaling claim. |
| 18 | Enough slides. Let's watch it happen. | Enough slides. Let's watch it happen. |
| 19 | I deploy the switch-on rule first. | The conflicting pair never exists in the active rule set. |
| 20 | Now I want to make the difference visible. | That is the whole point. Move the decision left, before the rules ever run. |
| 21 | We have counters. Somebody still has to interpret them. | That separation is more interesting to me than putting an LLM in front of every button. |
| 22 | So far, people wrote the rules. Now we let a model write them. Same gate, same question. | So far, people wrote the rules. Now we let a model write them. Same gate, same question. |
| 23 | The same boundary applies when the language model is the author. | We are not verifying the model itself. |
| 24 | The AI-policy detector has exactly seven categories of conflict. They are on the slide, so I will not read them all. | Nothing more heroic than that. |
| 25 | When the check finds a conflict, it comes back with a type. Approval gate bypass, for example. That gives the model something concrete to fix. | The model does not judge its own work. |
| 26 | This final demo is deliberately boring. | Nothing had to persuade itself that it was correct. |
| 27 | That was the last demo. Let me pull this together. | That was the last demo. Let me pull this together. |
| 28 | Maude is not the answer to every formal-methods problem. | Tool choice should follow the property, not loyalty to the tool I happened to put in a conference talk. |
| 29 | Before taking this toward production, keep the claim attached to its evidence. | It does not automatically satisfy a regulation, and it definitely does not prove a property we never modeled. |
| 30 | A fair question, especially now that Jev is out: why not a decision model instead of Maude? | The decision model asks what is likely. Maude asks what the model allows. |
| 31 | The code and notebooks from today are on GitHub if you want to try this, or break it. | Thank you. |

## Protected lines

- “You review one change. The system runs all of them together.”
- “A bad answer, a good answer, and no answer are three different things.”
- “For this demo, if the checker cannot answer, the rule is not activated.”
- “Maude made the decision. The language model explained what the system observed.”
- “Formal methods strengthen narrow claims. They cannot prove broad ones.”

## Practice method

1. Say the seven beats without slides.
2. Advance through `/talk` and say only each anchor and exit.
3. Add the middle in your own words while keeping the protected lines exact.
4. Rehearse once with the iPad notes visible, once using it only after a deliberate blank, and once with it disconnected.
5. Record the full run. Edit only where the same confusion happens twice.
