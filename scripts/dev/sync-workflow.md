# GitHub Sync Workflow

Since you're working in a GitHub Desktop folder, here are the best ways to keep everything synced.

## 🚀 Quick Sync Options

### Option 1: Use GitHub Desktop (Recommended)
**Best for:** Visual review of changes before committing

1. Open **GitHub Desktop**
2. Review changes in the left panel
3. Write commit message
4. Click **"Commit to main"**
5. Click **"Push origin"** button

**Advantages:**
- See exactly what changed
- Review diffs before committing
- Easy conflict resolution
- Visual history

---

### Option 2: Use Batch Scripts

#### Quick Sync (No Prompts)
**Double-click:** `quick-sync.bat`
- Fetches latest changes
- Pulls if needed
- Stages all changes
- Commits with default message
- Pushes to GitHub

**Best for:** When you're confident about changes

---

#### Full Sync (With Prompts)
**Double-click:** `sync-to-github.bat`
- Shows status
- Fetches latest changes
- Prompts if you're behind remote
- Lets you write custom commit message
- Pushes to GitHub

**Best for:** When you want control over the process

---

#### Check Status Only
**Double-click:** `check-sync-status.bat`
- Shows local changes
- Shows if you're ahead/behind
- Doesn't make any changes

**Best for:** Quick status check

---

## 📋 Recommended Workflow

### Daily Workflow

1. **Start of day:**
   ```bash
   # Check status
   check-sync-status.bat
   
   # Or pull latest
   git pull origin main
   ```

2. **During work:**
   - Make changes normally
   - Test your changes

3. **End of day / Before breaks:**
   ```bash
   # Full sync with review
   sync-to-github.bat
   ```

### Before Major Changes

1. **Sync first:**
   ```bash
   sync-to-github.bat
   ```

2. **Create feature branch (optional):**
   ```bash
   git checkout -b feature/slice-2-case-hub
   ```

3. **Work on feature**

4. **Sync when done:**
   ```bash
   sync-to-github.bat
   ```

---

## 🔄 Sync Strategies

### Strategy 1: Frequent Small Commits
- Commit after each small feature/change
- Use `quick-sync.bat` frequently
- Keeps history clean and easy to review

### Strategy 2: Daily Commits
- Work all day
- Commit once at end of day
- Use `sync-to-github.bat` with descriptive message

### Strategy 3: Feature-Based Commits
- Complete a feature (e.g., Slice 2)
- Commit with feature description
- Use `sync-to-github.bat` with detailed message

---

## ⚠️ Common Scenarios

### Scenario 1: "I'm behind remote"
**Solution:**
```bash
# Option A: Use sync script (handles it)
sync-to-github.bat

# Option B: Manual pull
git pull origin main
```

### Scenario 2: "I have conflicts"
**Solution:**
1. Use GitHub Desktop to resolve conflicts visually
2. Or manually edit conflicted files
3. Then run `sync-to-github.bat` again

### Scenario 3: "I forgot to sync for days"
**Solution:**
1. Check status: `check-sync-status.bat`
2. Review changes: `git status`
3. Sync: `sync-to-github.bat`
4. Write descriptive commit message about what you did

---

## 🛠️ Troubleshooting

### "Push failed - authentication"
**Solution:**
- Use GitHub Desktop to authenticate
- Or set up SSH keys
- Or use Personal Access Token

### "Branch name mismatch"
**Solution:**
```bash
# Check your branch name
git branch

# If it's 'master', use:
git push origin master
```

### "Remote not configured"
**Solution:**
```bash
git remote add origin https://github.com/TaimurCEMS/Legal-AI-App.git
```

---

## 📝 Best Practices

1. **Sync before starting new work** - Always pull latest first
2. **Write meaningful commit messages** - Helps track what changed
3. **Don't commit sensitive files** - Check `.gitignore`
4. **Test before committing** - Make sure app still works
5. **Use GitHub Desktop for conflicts** - Easier visual resolution

---

## 🎯 Quick Reference

| Action | Command/Script |
|--------|---------------|
| Check status | `check-sync-status.bat` |
| Quick sync | `quick-sync.bat` |
| Full sync | `sync-to-github.bat` |
| Pull only | `git pull origin main` |
| Push only | `git push origin main` |
| Visual sync | Use GitHub Desktop |

---

**Remember:** Since you're in a GitHub Desktop folder, you can always use GitHub Desktop for the safest, most visual sync experience!
