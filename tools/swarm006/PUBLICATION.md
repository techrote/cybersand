# Source publication through the connected GitHub API

The current shell has no HTTPS write credential or authenticated `gh` session.
The connected GitHub account can access `techrote/cybersand` with push permission.
These helpers use the available Git Data API tools without requesting a token,
changing accepted `main`, overwriting an experimental baseline, or marking a PR
Ready. Publishing is coordinated only after the native candidate is frozen.

## Prepare exact local objects

Commit the intended source and keep the worktree clean. Place the publication
directory outside the checkout. The native helper invocation is:

```bash
python3 tools/swarm006/prepare_publication.py \
  --root /path/to/native-checkout \
  --lane native \
  --base c178feeb39899fd155b7deb9d5bde3f50ee28548 \
  --target HEAD \
  --output /path/to/native-publication
```

For Workbench, first fetch and integrate the exact published native candidate,
preserving ancestry. Then use the verified Workbench baseline or a previously
published Workbench preparation descendant as first parent:

```bash
python3 tools/swarm006/prepare_publication.py \
  --root /path/to/workbench-checkout \
  --lane workbench \
  --base 8ec6d3c62197f3ef4088d79e4aa2910f5eaa36f7 \
  --additional-parent FULL_REMOTE_NATIVE_SHA \
  --target HEAD \
  --output /path/to/workbench-publication
```

The helper uses `git diff-tree` against that exact first parent. Only added or
changed Git blobs are exported; file modes, symlinks, Git links and deletions are
preserved. Unchanged files come from the base tree. Every blob is checked against
its Git SHA before encoding. The manifest records the target tree SHA and ordered
parents. It does not publish anything or contain credentials.

For a later update to the new SWARM-006 branch, fetch its live head and provide
that SHA as both `--base` and `--expected-remote-head`. The generated commit must
advance from the exact leased head. No force update is used.

## Publish through the orchestration tools

Read `publish_source.exec.js` and run its body with `functions.exec`, setting
`manifestPath` and `frozenTreeApprovedForPublication` explicitly after freeze
coordination. It uses only these connector mutations:

| Tool | Binding |
|---|---|
| `github_create_blob` | Base64 content; returned blob SHA must equal the manifest SHA. |
| `github_create_tree` | Verified base tree and changed paths; returned tree SHA must equal the complete local target tree. |
| `github_create_commit` | Exact tree, first parent and ordered additional parent SHAs. |
| `github_create_branch` | New SWARM-006 branch at the verified first parent, only when absent. |
| `github_update_ref` | Fast-forward to the verified remote commit with the expected-SHA lease. |

Independent blob uploads run in batches of four. Every outcome is inspected.
Tree and commit creation stop before a ref change if bytes or ancestry differ.
The publication receipt is written before publishing the ref so an interrupted
ref update can be inspected without blindly repeating it.

GitHub's commit tool supplies author/timestamp metadata. Consequently the remote
commit SHA differs from the local preparation SHA even when the entire source
tree and ancestry are exact. **Fetch and qualify the returned remote SHA.** Do
not describe local compilation logs as exact-HEAD evidence for that new SHA.
The publication receipt preserves the mapping and exact common tree hash.

## Draft PR and Windows trigger

After the ref is observed, create the native Draft/HOLD PR against its verified
native baseline branch. Create the Workbench Draft/HOLD PR against its verified
Workbench baseline branch and cross-link the exact native parent and programme
issue 704. `github_create_pull_request` takes `draft: true`, `head`, `base`, title
and structured multiline body. No Ready, merge or auto-merge call belongs here.

`swarm006-workbench-windows.yml` runs on pushes to
`experiment/gentek-swarm-006-workbench-recovery`. Creating the new branch at its
old baseline and then updating to the prepared commit provides the explicit push
that carries the new workflow. Draft PR state does not gate this workflow. It
checks out and asserts `github.sha` and builds the generator using the committed
`Makefile.reciprocal`, including the recovery implementation and custody code.

No workflow-dispatch connector is available in this session. Initial execution
therefore uses the branch push. Once a run exists, the connector can fetch jobs,
logs and artifacts and rerun a failed job on its original source. Manual dispatch
is not a reason to import the workflow into `main`.

`github_fetch_commit_workflow_runs` filters to pull-request-triggered runs; it
must not be used to infer that this push-triggered workflow did not run. Query
the repository runs endpoint with the exact head SHA and inspect event/path, or
fetch the observed run ID directly. Keep retries and prior failed logs separate.

## Known qualification limits before publication

- API source-object writes and workflow-file permissions are only fully proven
  when the authorized publication executes; no mutation was used for this
  credential preflight.
- Actual Windows source and pristine-package runs remain required. Local
  Godot 4.7.2 synthetic checks do not qualify the pinned 4.7 Windows evaluator.
- Documentation qualification uses the exact two-checkout layout from
  `documentation.yml`: companion commit
  `6a58311982941b75f46e22109a0829e5acb83c7e` at `workspace`, with source at
  `workspace/source`. Six expected-fact citations intentionally resolve into
  that companion. The isolated-checkout failure was a layout mismatch; the
  pinned nested layout passes without altering fixtures or historical files.
- Owner NVIDIA acceptance remains separate from automated Windows graphics.
