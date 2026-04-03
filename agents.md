# Agent Handbook

## Purpose & References
This handbook covers only how to collaborate with the maintainer on this repository. For stack, setup, or environment details, consult existing project documentation (e.g., `README.md`)—do not restate or paraphrase it here.

## Instruction Scope
Follow only the sections and rules defined in this handbook. Do **not** introduce new sections, policies, or workflows without explicit authorization from the maintainer.

## Complete Lists
Whenever you present a list (plans, findings, options, etc.), provide every relevant item—never respond with a partial list.

## Answer Questions First
Always answer any question from the maintainer before proceeding with additional work, unless the work is strictly required to answer that question. Explicitly acknowledge the question and your intent in your reply.

## Migration Safety
Never modify an existing migration file—even one you authored—without explicit permission. If you believe a change is required, pause, explain why, and request approval before doing anything.

The user likes running thier own migrations. when working on a task, once the migrations are in a good place, ask the user to run them for you. 

## Handling Tooling Limits
If sandbox limits prevent you from running migrations, tests, or other project commands, stop immediately. Report what you attempted, note the failure, and ask the maintainer to run the command and share the output. Do not attempt alternative workarounds.

If you can’t run a command (for example `bundle exec rails test`) because the sandbox lacks the expected Ruby environment, run `eval "$(rbenv init -)" && rbenv shell 3.3.6` before retrying. When Postgres connections are blocked, ask the maintainer to loosen approval restrictions so the database can accept connections.


## Session Kickoff
When a new collaboration session begins, read this handbook and acknowledge explicitly that you have done so before taking any action.

## Referenced Resources
If the maintainer references a file, image, or other resource that you cannot access or do not find, pause and ask for clarification or an alternative before proceeding.

## Subagent Rule

- Use subagents when they are available and materially useful.
- Prefer delegating bounded, parallelizable work instead of doing everything in the main agent.
- Keep urgent critical-path work in the main agent when waiting on a subagent would slow things down.
- Only use `gpt-5.4` or `gpt-5.4-mini` for subagents.
- Choose reasoning effort to fit the task instead of defaulting high.
- Prefer lower reasoning for routine frontend and UI work.
- Prefer `gpt-5.4` with higher reasoning for harder debugging, backend changes, and ambiguous tasks.
