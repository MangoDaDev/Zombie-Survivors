# Source guidance

- This tree contains project-owned runtime code mapped by `default.project.json`.
- Preserve the separation between client bootstrap, server bootstrap, controllers, shared modules, loading UI, and application UI.
- Code under `modules` replicates to clients. It must not contain server-only secrets or unguarded server-only behavior.
- Put substantial behavior in focused controllers or modules rather than bootstrap scripts.
- Place reusable code in the narrowest suitable existing folder and avoid circular dependencies.
- Do not add placeholder modules merely to populate an otherwise empty template folder.
- Inherit naming, networking, persistence, security, and cleanup rules from the root `AGENTS.md`.
