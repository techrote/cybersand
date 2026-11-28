# Historical predecessor archive failure and bounded importer diagnosis

This review preserves a failed earlier campaign and the existing final-source
remedy. It does not replace the original Windows failure with a local pass.

## Original failure

Sequence 5, application `146cead1ac41147efa993b0bf8b634da08695182`, ran in
[45720008446](https://github.com/techrote/cybersand/actions/runs/45720008446).
Its Windows optical and inherited authoring work completed, but the paired
original-934 comparison stopped during the original application's bootstrap:

`Original production source changed during observation: addons/godot-rapier2d/logo_square_2d.png.import`

There were **zero paired observation cases** in that failed campaign. Its
controls artifact `15077667232` is 70,702,417 bytes with SHA-256
`ec1551cad5a6b8dee6ea0719ac2f396638f3913d4e83deaa69f8eada0bcf0e74`.
The original full Windows artifact is `15077672130`, 142,353,572 bytes, SHA-256
`7203c34792a918a0922380773ef9b1c55d0ef4b5d5c68f84d2d587463c3151e5`.
The artifacts remain original; neither is relabelled as the final application.

The retained source-custody record expected import metadata hash
`e19e505076e4d2a7cce0af093d27f1e2d99c281ca21d5a584c38bd63b484bf48`.
The committed original-934 Git blob, with LF line endings, has hash
`2f5527b8bea78ee1ca403de3de46844b375a8f1fff140994171a75ebd79dfd07`.
Converting that exact blob to CRLF reproduces the failed campaign's expected
hash. This establishes an archive-line-ending discrepancy. The historical
post-import file was not retained, so its exact resulting bytes are unknown.

## Isolated reproduction

The lead staged the original-934 PNG and its CRLF import metadata in a minimal
separate Godot project, preserving the original relative path. Pinned official
Godot 4.7 ran `--headless --editor --path PROJECT --quit` with Compatibility as
the project's renderer setting. It exited 0 and rewrote only CRLF to LF. The
resulting import metadata was byte-identical to the original Git blob.

The compact [diagnostic receipt](predecessor-crlf-import-diagnostic.json)
preserves the exact PNG, before/after metadata, Godot and raw-log hashes plus
the command and result. The actual local raw log remains outside Git in
accordance with repository policy. This was a Linux importer experiment,
**not a Windows graphical run or proof of the historical post-import bytes**.

## Existing final-source correction and fresh outcome

The frozen final application `fd0830abcfadd9ae19162e5677943bb131223e59`
already supplies a child-only Git archive environment with
`core.autocrlf=false` and `core.eol=lf` in
`tools/ci/strata3_predecessor_compare.py`. No global user Git setting is changed,
and no source-custody check is removed. This normalizes the original archive to
its committed LF bytes before Godot is launched.

The final run
[45721790366](https://github.com/techrote/cybersand/actions/runs/45721790366)
completed the actual Windows inherited and six-process paired comparison job
successfully. That is a new, separately source-bound execution. The separate
Linux-side reader portability issue for retained Windows command basenames is
tracked independently; it is not the historical archive newline failure.
