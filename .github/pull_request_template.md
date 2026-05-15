## Summary

<1-3 sentences: what this PR does and why.>

## Type

- [ ] New tool under `tools/`
- [ ] Template change (`people/_template/` or `projects/_template/`)
- [ ] Doc update (`README.md`, `AGENTS.md`, `CLAUDE.md`)
- [ ] CI / repo plumbing
- [ ] Bug fix

## Privacy checklist (must pass)

- [ ] No real names, emails, phone numbers, WeChat IDs, or chat excerpts in diff
- [ ] No files added under `people/<name>/`, `projects/<name>/`, `topics/<name>/` outside `_template/`
- [ ] No `.db`, `.sqlite`, `.pdf`, `.docx`, `.xlsx`, `.pptx` files committed
- [ ] All examples use placeholders (`张三`, `Alice`, `Acme Corp`)

## Cross-platform

- [ ] PowerShell scripts have UTF-8 setup at top
- [ ] Scripts validate inputs and surface errors clearly
- [ ] If adding a `.ps1`, considered whether a `.sh` equivalent is needed

## Docs

- [ ] `README.md` updated if user-visible behavior changed
- [ ] `AGENTS.md` / `CLAUDE.md` updated if agent workflow changed

## Test plan

<How did you verify this works? Include commands run + expected output.>
