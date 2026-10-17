# Project instructions

## Coding style and code generation

Before generating or modifying project-owned GDScript, read and follow the
[GDScript Coding Style Guide](editor_only_debug/markdown_documentation/Project%20Documentation/Guidance/GDScript%20Coding%20Style%20Guide.md).
Apply it to new scripts, generated snippets, and changes to existing scripts.
Use its guidance for legacy indentation, runtime resource loading, and intentional
test output; preserve behavior and existing resource/save identities during style
work. Review changed code against its checklist before completing the task.

## Battle Workshop work — deferred

Battle Workshop is not a current priority. Its plan is a deferred editor-plugin
reference, not a prerequisite for runtime battle, action, item, or skill-tree work.
Do not read, update, implement, or carry its milestones into unrelated tasks merely
because they touch Resources the future plugin might use. Revisit the specification
against the then-current runtime only when Workshop work is explicitly requested.

The canonical implementation specification is
[Battle Workshop Implementation Plan](editor_only_debug/markdown_documentation/Project%20Documentation/Plans/Battle%20Workshop%20Implementation%20Plan.md).

Only for tasks explicitly targeting Battle Workshop planning, implementation,
testing, or review:

1. Read that document before changing code. Review its implementation ledger,
   required contracts, and the milestone being worked on.
2. Follow milestone dependencies and acceptance criteria. Keep existing battle
   behavior and resource/save identities compatible unless the user explicitly
   changes the requirements.
3. Update the document in the same work batch when decisions, implementation
   status, API findings, or verification results change. Distinguish planned,
   implemented, and actually verified behavior.
4. Include the canonical document path, current milestone, completed checks,
   unresolved issues, and next step in continuation/handoff summaries so this
   reference survives conversation compaction and task changes.
5. Resolve conflicts using the latest explicit user direction; update the plan
   to record the resulting decision rather than silently following stale text.

This reference does not authorize implementing the plugin during a documentation
task, enabling production content, or migrating existing player saves.
