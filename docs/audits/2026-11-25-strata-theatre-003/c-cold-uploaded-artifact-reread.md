# C independent re-read of the uploaded cold evidence

**PASS — the unchanged observer reader accepted the actual uploaded artifact. Application PERFORMANCE HOLD is unchanged.**

After local execution became available again, C downloaded the original cold
evidence artifact and the original owner evaluator artifact, verified their exact
sizes and SHA256 digests, and ran the unmodified portable reader at observer
`92ec0280bba341b49345f292c4f89331b11a341b`. The reader exited **0**, emitted
`verified: true`, and produced **zero stderr bytes**. This adds an actual local
read of the uploaded originals to the earlier hosted source/log review; that
earlier review remains unchanged.

## Source and artifact identities

| Item | Exact identity |
| --- | --- |
| Application | `fd0830abcfadd9ae19162e5677943bb131223e59` |
| Application tree | `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499` |
| Unmodified observer | `92ec0280bba341b49345f292c4f89331b11a341b` |
| Observer tree | `25dbd1371fa052e5f02de32c57e585d1b4846981` |
| Reader source SHA256 | `78d345ccdeef3ad5f98fe297ef190047306bc1f47f08fe5bcfb9da5a84788005` |
| Hosted cold run / job | [45743337775](https://github.com/techrote/cybersand/actions/runs/45743337775) / `139653387374` |
| Uploaded cold artifact | [15082655904](https://github.com/techrote/cybersand/actions/runs/45743337775/artifacts/15082655904), 635,667 bytes |
| Uploaded cold ZIP SHA256 | `8bae9a314d010f5bbe09637bd217c6d15948316a783437d24bfeb76208311e9e` |
| Owner evaluator artifact | [15080761776](https://github.com/techrote/cybersand/actions/runs/45721790366/artifacts/15080761776) |
| Outer evaluator SHA256 | `cc6d27dbf377cb62ac397c2db0b3ba6f9b2f3b3b294a3bc89b7fbbc18767b1ee` |
| Inner evaluator SHA256 | `f76a5b718c89c5906f8c6f51fdf9ece5f9bbd7c51601352b226c429b8a2daa07` |
| Manifest SHA256 | `a2531d05f17227448c5dd2264e59a472df87ec2d079fa68d6cc707aa5580197c` |

The cold ZIP contains **15 original files**, totaling 2,153,105 uncompressed
bytes. The complete 14-file ledger agrees exactly with the extracted files;
the root `cold-launch.json` is the sole intentionally excluded self-record.
The uploaded hidden source
`observer/.github/workflows/strata-theatre-003-cold-launch.yml` is present and
has SHA256
`9538919d61d5712a80c926b0392f6d2f993fe595b79dcd5696c9a43222f712da`.
This directly closes the uploaded hidden-workflow inventory concern.

The evaluator outer ZIP is 477,073,937 bytes and contains the three expected
members. Their CRC checks passed. The inner ZIP is 477,296,145 bytes with
**2,549 members**. The unchanged reader streamed and checked the complete
inner payload against the exact embedded manifest. The supplied sidecar
manifest is byte-identical to that embedded manifest.

## Independent execution

The observer was checked out detached at the exact commit/tree above, with a
clean status before and after verification. The command was:

```sh
python3 tools/ci/strata3_cold_launcher.py verify \
  --output /tmp/strata003-cold-upload-review/evidence \
  --package-archive /tmp/strata003-cold-upload-review/owner-package/CyberSand-Strata3-Workbench-Windows-fd0830abcfad.zip
```

The working directory was `/tmp/strata003-cold-reader-92ec`. The portable
reader ran on Linux against the original Windows evidence. No compatibility
adapter, modified predicate, rewritten receipt, Godot invocation, native turn,
or new application execution was involved.

The final JSON was 1,479 bytes, SHA256
`0f4d554c3fe708d06c478245d506768e05b3e0552a5de3b44dc357914cf8b3e8`.
Its admitted observation matches the original hosted observation. The uploaded
`cold-launch.json` SHA256 is
`1f1001183dfc5a2a7dfe49cac05c5113e913ebb606978f442ad1b84644f3251b`.
The companion [machine-readable receipt](c-cold-uploaded-artifact-reread.json)
retains the full file inventory, source inputs, actual command, interpreter
version, original identities, and strict-reader result.

## What this closes

The published cold artifact contains the complete source and observation
inventory required by its unchanged reader. Its successful hosted execution
survives an independent portable re-read of the actual uploaded ZIP, including
the original process log, held-handle lifetimes, sampled resources, payload
inventory, request and hidden workflow source. The exact delivered evaluator
is the one checked by that reader.

The original observer-v1 rejection remains preserved. This later evidence
does not retroactively qualify it or replace the earlier source/log review.
The successful cold run still measured a 11.1453828-second import command,
a 78.8635987-second ordinary Workbench command, and a 90.025416-second complete
CMD lifetime. These are process lifetimes, including their documented session
and teardown scopes; they are not scene-admission latency.

No rendering, native authority, optical quality, physical progression, or
performance gate changed. The registered 45-second scene-admission target,
its recorded failures, enabled-optics PERFORMANCE HOLD, and physical Windows
11/NVIDIA owner acceptance remain in force.

## Recovered detailed reviews

The workspace outage removed temporary directories but preserved the shared
repository's Git objects. C restored the original worktree without changing
application files. These original detailed reports remain recoverable exactly:

- Commit `dd490a68`: `c-shader-cost-v2-actual-review.md` and `.json`.
- Commit `5d63fc12`: `c-windows-owner-ui-motion-review.md` and `.json`.
- Commit `ce9884f1`: the original `owner-feedback-route.md`; later archived
  navigation corrections retain their own scope and should be preserved.

Those committed reports are distinct from the compact recovery notes written
while local execution was unavailable. Raw temporary captures and process logs
must still be recovered from their source-bound original artifacts when needed.
