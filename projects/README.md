# projects/

One directory per work / personal project you're tracking.

- `_template/` — scaffold for new project notes. Copy and rename.
- `<your-slug>/` — gitignored, holds source materials (PDFs, docs), extracted text, `notes.md`, and any generated dashboards (`task-plan.html`).

## Create a new project

```powershell
Copy-Item -Recurse projects\_template projects\acme-q2-launch
# Drop source PDFs into projects/acme-q2-launch/
# Extract text:
node tools\extract-pdf.js projects\acme-q2-launch\spec.pdf 1 30 > projects\acme-q2-launch\spec-p1-30.txt
# Have your agent read the extracts and update notes.md
```
