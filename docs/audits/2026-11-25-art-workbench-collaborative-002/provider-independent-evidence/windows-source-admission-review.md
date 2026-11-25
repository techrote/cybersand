# Windows source-admission finding: retained evidence and isolated reproduction

The intermediate principal Art campaign `45534980763` at source `2743f89a0df6f6afcf7484e859c10790d521e74b` completed its inherited Windows regression groups, then both fresh collaborative suites refused before execution because the strict `git status --porcelain` source guard found tracked modifications. Those seven new cases and the Windows package were not qualified by this campaign.

Artifact `14988050882`, SHA-256 `038fed40c87a04ec3d26669b47612af8cc9bfe5ffd166729256fa8fe285fb42c`, was independently downloaded, hash-checked and ZIP CRC checked (530 members). All 12 retained prior `provenance.json` files report an empty `source.changed_paths` and empty selected diff. Their older collector uses `git diff --name-only`; the strict new guard uses porcelain status. No actual failed porcelain/status/diff was retained in this artifact.

The job repeatedly reports LF-to-CRLF warnings for the four tracked Rapier import descriptors. That is evidence of EOL conversion, not direct proof of the failed dirty-path inventory.

[The exact-byte reproduction source](reproduce_import_eol.py) and [complete result](import-eol-reproduction.json) show a supported mechanism using all four descriptors from exact source 2743 in a disposable Linux Git repository with `core.autocrlf=true`: a fresh checkout has CRLF and is clean; a Godot-style LF rewrite gives four porcelain modifications while `git diff --name-only` is empty. Explicit `*.import text eol=lf` leaves both fresh checkout and identical rewrite clean. Local Git version is recorded in the result. This is an independent mechanism reproduction, not an unrecorded Windows inspection.

The proposed correction pins LF for this generated-descriptor format and retains failure status, cached/uncached diff and per-path byte identities. It must preserve strict source refusal; no automatic restoration or broad import-file exemption is justified. A fresh exact-source Windows campaign must establish the correction's actual effect.
