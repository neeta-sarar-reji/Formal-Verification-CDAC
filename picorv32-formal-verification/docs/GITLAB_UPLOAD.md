# Publishing this repository to GitLab

## A. One-time setup
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```
Authentication (choose one):
- **HTTPS + personal access token:** GitLab > avatar > Preferences > Access Tokens. Scopes: `write_repository` (and `read_repository`). Use the token as the password when git asks.
- **SSH key (recommended):**
```bash
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub        # paste into GitLab > Preferences > SSH Keys
ssh -T git@gitlab.com            # test (use your organisation's host if self-hosted)
```

## B. Create the empty project on GitLab
GitLab > New project > Create blank project. Name e.g. `picorv32-formal-verification`. Choose visibility as your lead specifies. **Untick "Initialize repository with a README"** (the repo already has one).

## C. Push
```bash
unzip picorv32-formal-verification.zip
cd repo                                  # or the folder name you renamed it to
git init -b main
git add .
git status                               # check: no external/, no *.vcd, no build folders
git commit -m "PicoRV32 formal verification: riscv-formal, memory proof, Verilator sim"
git remote add origin git@gitlab.com:<group-or-user>/picorv32-formal-verification.git
# HTTPS alternative: https://gitlab.com/<group-or-user>/picorv32-formal-verification.git
git push -u origin main
```

## D. Add your real results before the final push
```bash
scripts/00_fetch_sources.sh
scripts/03_riscv_formal.sh 4 && scripts/04_summarize.sh
scripts/02_mem_formal.sh && scripts/05_simulate.sh && scripts/01_lint.sh
scripts/record_versions.sh
```
Then edit the `[FILL]` markers in README.md (name, date, `isa` line, job counts) and:
```bash
git add -A
git commit -m "Add results and fill README details"
git push
```
Do not commit `external/`, `*.vcd` or build folders (the `.gitignore` already excludes them). The files in `results/` are small and should be committed.

## E. Optional: pin the third-party sources as submodules
Records exact upstream versions inside the repo:
```bash
git submodule add https://github.com/YosysHQ/picorv32.git external/picorv32
git submodule add https://github.com/YosysHQ/riscv-formal.git external/riscv-formal
git commit -m "Pin picorv32 and riscv-formal"
git push
```
Remove `external/` from `.gitignore` first. Anyone cloning then uses `git clone --recurse-submodules <url>`. To pin the versions you actually used, check them out inside each submodule at the commit hashes in `results/tool_versions.txt` before committing.

## F. Common problems
| Problem | Fix |
|---|---|
| `Permission denied (publickey)` | Add the public key to GitLab; test with `ssh -T` |
| `remote: HTTP Basic: Access denied` | Use a personal access token, not the account password |
| `failed to push ... non-fast-forward` | The project was created with a README: `git pull --rebase origin main`, then push |
| Large file rejected | Check `git status` for `.vcd` or build output; remove with `git rm --cached` |
| Self-hosted GitLab | Replace `gitlab.com` with your organisation's host |
