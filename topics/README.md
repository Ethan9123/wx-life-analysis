# topics/

Cross-chat keyword searches via `wx search`. One directory per topic slug.

`<your-slug>/search.json` files are gitignored.

## Search a topic

```powershell
$slug = "boardgame"
New-Item -ItemType Directory -Force -Path "topics\$slug" | Out-Null
wx search "桌游" -n 500 --json | Out-File "topics\$slug\search.json" -Encoding utf8
```
