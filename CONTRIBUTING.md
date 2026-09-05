# Contributing

This repository maintains Elisante Nkini's public GitHub profile. `README.md`
is the profile itself; keep developer documentation in separate files.

## Workflow

1. Start from the latest `main` and create a short-lived branch:

   ```sh
   git switch main
   git pull --ff-only
   git switch -c docs/describe-change
   ```

2. Make a focused change and preview the README on GitHub.
3. Run the same checks used in CI (PowerShell 7 and Git required):

   ```sh
   pwsh -NoProfile -File scripts/check-repo.ps1
   git diff --check
   ```

4. Commit with a descriptive message, push the branch, and open a pull request.

## Content and formatting

- Use UTF-8, LF line endings, and the settings in `.editorconfig`.
- Keep professional claims accurate and supported by experience or project work.
- Describe AI learning and interests without implying unverified expertise.
- Clearly distinguish recent work from public repository language statistics.
- Preserve descriptive link labels and image alt text.
- GitHub strips `target="_blank"` from rendered README links. The attributes in
  the source only affect renderers that support them.
- Avoid adding package managers or application build tooling to this profile repo
  unless the project grows to need them.

## Personal files

Resume drafts, contact details, credentials, and private project information
should not be committed. Resume files are ignored by default. Publishing a
resume is a separate decision: prepare a reviewed public copy before changing
the ignore rules or repository checks.

## Checks

The Repository checks workflow runs on pushes, pull requests, and manual runs.
It validates tracked text formatting, unresolved merge markers, and tracked
resume filenames. It does not scan file contents for all possible secrets,
check remote link availability, or verify rendered layout; preview visual
changes before merging.
