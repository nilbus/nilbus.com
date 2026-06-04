---
name: deploy
description: Deploy the Brainaural/tones app from this repository to the sibling nilbus.com repository's gh-pages branch. Use when the user asks to deploy, publish, ship, or update Brainaural/tones on nilbus.com from committed changes in this repo.
---

# Deploy Brainaural

Deploy committed changes from this repository into the sibling `../nilbus.com` repository, where `gh-pages` is published by GitHub Pages and the local remote `tones` points back to this repo.

## Workflow

1. From the Brainaural repo, check whether there are uncommitted changes:
   ```bash
   git status --short
   ```
   Only already-committed changes are deployed. If the user expects uncommitted changes to ship, stop and ask whether to commit them first.

2. Confirm the sibling deployment repo and remote exist:
   ```bash
   test -d ../nilbus.com/.git
   git -C ../nilbus.com remote -v
   ```
   The `../nilbus.com` repo must have a local remote named `tones` that points to this repo.

3. Run the deployment commands in `../nilbus.com`:
   ```bash
   cd ../nilbus.com
   git checkout gh-pages
   git pull
   git fetch tones
   git merge --no-commit tones/master
   git rm -r --cached --sparse tonesApp/
   git commit -m "Merge tones/master into gh-pages (excluding tonesApp/)"
   git push
   ```

4. Open the GitHub Actions page to monitor the deployment:
   ```bash
   open https://github.com/nilbus/nilbus.com/actions
   ```

## Handling problems

- If `git merge --no-commit tones/master` reports conflicts, do not push. Resolve or ask the user how to resolve, then continue only after `git status` is clean enough to commit.
- If there is nothing to commit after removing `tonesApp/` from the index, skip the commit/push and tell the user the deployment branch is already up to date.
- Keep all deployment git commands scoped to `../nilbus.com`; do not commit in this repo as part of deployment unless the user explicitly asks.
