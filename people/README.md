# people/

One directory per WeChat contact you're tracking.

- `_template/` — scaffold for new profiles. Copy and rename.
- `<your-slug>/` — gitignored, holds the actual data (`chat.md`, `sns.json`, `profile.md`, `.last-sync`, etc.)

Use ASCII slugs for directory names (`zhangsan`, not `张三`) — easier to type, fewer encoding headaches.

## Create a new person

```powershell
# Copy template
Copy-Item -Recurse people\_template people\zhangsan

# Pull data
.\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"

# Then have your agent read chat.md and fill in profile.md
```
