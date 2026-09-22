# Learn the talk — seven beats and twenty-six anchors

The full wording lives in [`manuscript.md`](./manuscript.md) and on the private iPad notes view. It is a recovery aid, not a memorization assignment.

Learn only three layers:

1. The seven-beat story below.
2. The first sentence—the anchor—of each slide.
3. The five protected lines at the end of this document.

Everything between an anchor and an exit can be said naturally from the slide. If you blank, read the current iPad block, look back at the room, and continue. Do not apologize.

## The seven-beat story

1. Two reasonable rules can fight when they run together.
2. That relationship exists before deployment.
3. A formal checker can answer one small, precise question.
4. The gate must keep `clean`, `conflicts`, and `unverified` separate.
5. Check the same rule the runtime will execute.
6. The live comparison shows the effect of stopping the conflict early.
7. Probabilistic models can judge uncertainty; formal models decide the invariants we explicitly encode.

## Slide anchors

| Slide | Anchor | Exit |
|---:|---|---|
| 1 | This talk is about bugs where every part works and the system still does the wrong thing. | Formal verification can answer that, as long as the question stays small. |
| 2 | This comes from the published smart-home study SOTERIA. In its multi-app evaluation, O3 and O4 react to the same contact-open event with conflicting switch values. | Our simulator gives us somewhere safe to make that conflict noisy. |
| 3 | This is what makes these bugs annoying. | That gap between local correctness and composed behaviour is where today's talk lives. |
| 4 | Nobody designed the combined behaviour on this slide. | We are perfectly capable of getting there by composing sensible things. |
| 5 | The relationship between these rules exists before a device moves, before an alert fires, and before deployment. | That is the architectural move. |
| 6 | Why not just write more tests? | We are asking it a specific question we bothered to define. |
| 7 | Maude looks intimidating at first. For this talk you need about four words. | That distinction matters because different Maude commands answer different questions. |
| 8 | reduce is not search. | We ask the narrow question we actually modeled. |
| 9 | This demo has four categories. | It is also easy to forget once the word formal appears on a slide. |
| 10 | What does a clean result mean? | It is also one I can defend. |
| 11 | Inside this Elixir application, Maude is not a sacred process living on a university workstation somewhere. | The process lifecycle does not have to be. |
| 12 | This is probably the implementation decision I care about most. | It makes the boundary smaller, and smaller boundaries are easier to test. |
| 13 | The gate has three answers. Not two. | It is application policy we chose explicitly. |
| 14 | Formal checking does not make the plumbing trustworthy by association. | Otherwise the formal core can be perfectly correct while the glue quietly lies. |
| 15 | Comparing every rule with every other rule is not particularly clever. | Those are today's run counts, not a universal scaling claim. |
| 16 | Okay. Enough slides. Let's actually do it. | The conflicting pair never exists in the active rule set. |
| 17 | Now I want to make the difference visible. | That is what I care about — moving the decision left, before runtime experiences the disagreement. |
| 18 | We have counters. Somebody still has to interpret them. | That separation is more interesting to me than putting an LLM in front of every button. |
| 19 | The same boundary applies when the language model is the author. | We are not formally verifying the language model. |
| 20 | The AI-policy detector has exactly seven categories. They are on the slide, so I will not read them all. | Nothing more heroic than that. |
| 21 | A typed conflict gives a probabilistic author something concrete to revise. | The author does not grade its own work. |
| 22 | This final demo is deliberately boring. | Nothing had to persuade itself that it was correct. |
| 23 | Maude is not the answer to every formal-methods problem. | Tool choice should follow the property, not loyalty to the tool I happened to put in a conference talk. |
| 24 | Before taking this toward production, keep the claim attached to its evidence. | It does not automatically satisfy a regulation, and it definitely does not prove a property we never modeled. |
| 25 | There is a timely question here: why not use Jev instead of Maude? | Jev asks what is likely. Maude asks what the model allows. |
| 26 | The code and notebooks from today are on GitHub if you want to try this, or break it. | Thank you. |

## Protected lines

- “You review one change. The system runs all of them together.”
- “A bad answer, a good answer, and no answer are three different things.”
- “For this demo an unverified candidate is not deployed.”
- “Maude made the decision. The language model explained what the system observed.”
- “Formal methods strengthen narrow claims. They cannot prove broad ones.”

## Practice method

1. Say the seven beats without slides.
2. Advance through `/talk` and say only each anchor and exit.
3. Add the middle in your own words while keeping the protected lines exact.
4. Rehearse once with the iPad notes visible, once using it only after a deliberate blank, and once with it disconnected.
5. Record the full run. Edit only where the same confusion happens twice.
