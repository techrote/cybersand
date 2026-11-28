#!/usr/bin/env python3
"""Publish the immutable independent focused-engine replay and bounded readouts."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import zipfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace-root', type=Path, default=Path('/workspace/scratch/0b2a9bdf7883'))
p.add_argument('--repository', type=Path)
args = p.parse_args()
base = args.workspace_root.resolve()
repo = args.repository.resolve() if args.repository else base / 'cybersand-qualification'
audit = repo / 'docs/audits/2026-11-24-pubpres-playability-final'
packet = audit / 'focused-font'
packet.mkdir(parents=True, exist_ok=True)


def need(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


incoming = base / 'evidence-c/focused-font-complete-independent-replay.json'
need(sha(incoming) == '9bf58d62571451b0ba220b54d8792a3c031a073152dd2b01d9dc7a0948e9c2bb', 'Original complete replay changed')
report = json.loads(incoming.read_bytes())
archive = base / 'evidence-root/font-requalification-01/original.zip'
need(sha(archive) == report['archive_sha256'], 'Original artifact changed')
need(report['complete'] is True and report['failures'] == [], 'Incomplete peer replay')
resources = {'schema': 'pubpres-focused-font-resource-readouts-v1', 'archive_sha256': sha(archive),
             'reader_sha256': sha(Path(__file__)), 'arms': [], 'complete': False,
             'scope': 'Actual owned process RSS query ledger is recomputed independently. CPU evidence has already passed the source-bound sampler replay. Whole-process samples include setup/cleanup and cannot supply capture-aligned CPU per physics step. No GPU-memory or utilization inference.'}
with zipfile.ZipFile(archive) as bundle:
    for case in report['cases']:
        for arm in case['arms']:
            prefix = arm['member']
            process = json.loads(bundle.read(prefix + '/process.json'))
            raw = bundle.read(prefix + '/process-memory.json')
            memory = json.loads(raw)
            need(memory and all(type(row['pid']) is int and row['pid'] == process['observed_application_pid']
                                and isinstance(row['elapsed_ms'], (int, float)) and not isinstance(row['elapsed_ms'], bool)
                                and math.isfinite(row['elapsed_ms']) and row['elapsed_ms'] >= 0 for row in memory),
                 'Memory ledger has an invalid process or clock')
            need(all(b['elapsed_ms'] >= a['elapsed_ms'] for a, b in zip(memory, memory[1:])), 'Memory clocks regressed')
            for row in memory:
                need(all(row.get(key) is None or type(row[key]) is int and row[key] >= 0
                         for key in ('rss_bytes', 'peak_rss_bytes', 'virtual_bytes', 'commit_bytes')),
                     'Memory scalar domain differs')
            peaks = [row['peak_rss_bytes'] for row in memory if row.get('peak_rss_bytes') is not None]
            rss = [row['rss_bytes'] for row in memory if row.get('rss_bytes') is not None]
            need(peaks and max(peaks) == process['sampled_peak_rss_bytes'] == arm['memory']['sampled_peak_rss_bytes'],
                 'Reported sampled kernel peak differs from actual query ledger')
            resources['arms'].append({'case': case['case'], 'index': arm['index'], 'render_thread': arm['render_thread'],
                'process_id': process['observed_application_pid'], 'memory_trace_sha256': hashlib.sha256(raw).hexdigest(),
                'samples': len(memory), 'missing_peak_samples': len(memory) - len(peaks),
                'maximum_sampled_instantaneous_rss_bytes': max(rss), 'maximum_queried_kernel_peak_rss_bytes': max(peaks),
                'cpu': arm['observers']['cpu'], 'presentation_observer_total_usec': arm['observers']['presentation']['observer_total_usec']})
resources['complete'] = len(resources['arms']) == 8
need(resources['complete'], 'Missing resource arm')
(packet / 'resource-readouts.json').write_text(json.dumps(resources, indent=2) + '\n')
for origin, name in ((incoming, 'independent-replay.json'),
                     (base / 'evidence-c/replay_focused_font.py', 'replay.py'),
                     (Path(__file__), 'build_packet.py')):
    need(origin.is_file(), 'Missing executed reader')
    shutil.copyfile(origin, packet / name)
need(sha(packet / 'replay.py') == report['reader_sha256'], 'Reader differs from executed replay')


def fixed(value, digits=3):
    return f'{value:.{digits}f}'


lines = [
    '# Focused font ownership repair: exact execution and independent decision', '',
    '**Disposition: the font ownership repair passes its registered startup and byte-history gates; Separate rendering is rejected as a playability improvement for both measured workloads. Everything remains Draft/HOLD.**', '',
    'This is a new execution of retained application/native/engine bytes, with a separately committed corrected qualifier. It does not rewrite the earlier red workflow. Every physical result below comes from independently witnessed actual Rapier completions; upload-call duration, draw notifications and step-selection counters supply no physical credit.', '',
    '## Contents', '',
    '- **Identity and custody** — exact old application, new driver, engine/runtime files and original artifact.',
    '- **Correctness and negative controls** — original Separate failure, repaired font/startup and both first-read GPU histories.',
    '- **Physical decision** — all eight first-144-step arms, including adverse controls and tail counts.',
    '- **Freshness and costs** — submitted-pose/material ages, real process CPU/RSS and observer limitations.',
    '- **Architectural consequence and limits** — what faster submission answers, and the remaining display/NVIDIA requirements.',
    '- **Reproduction** — exact replay, immutable packet and bounded temporary extraction.', '',
    '## Identity and custody', '',
    '| Item | Exact identity |', '|---|---|',
    '| Application | `c2f8a73d34448bc1496ecd84bca02f0812c80d27` |',
    '| Application tree | `351b947a50ce054361660eba9379006122527547` |',
    '| Execution driver | `d4f4afe93d02192d9165622b78b762d9fbf8dc3e` |',
    f'| Driver tree | `{report["driver"]["source_tree"]}` |',
    '| Focused workflow | [45467136551](https://github.com/techrote/cybersand/actions/runs/45467136551), original conclusion **SUCCESS** |',
    '| Retained engine/native build | [45452580606](https://github.com/techrote/cybersand/actions/runs/45452580606), application `c2f8a73d…` |',
    '| Focused artifact | `14959055513`; 20,857,561 bytes; 947 ZIP members |',
    f'| Focused ZIP SHA-256 | `{report["archive_sha256"]}` |',
    f'| Repaired GUI SHA-256 | `{report["engine_sha256"]}` |',
    f'| Repaired build proof SHA-256 | `{report["engine_proof_sha256"]}` |',
    f'| Original #609 GUI SHA-256 | `{report["original_engine_sha256"]}` |',
    f'| Native Windows DLL SHA-256 | `{report["native_runtime"]["binary_sha256"]}` |',
    f'| Native manifest SHA-256 | `{report["native_runtime"]["manifest_sha256"]}` |',
    f'| Rapier Windows DLL SHA-256 | `{report["rapier"]["sha256"]}` |',
    f'| Full independent replay SHA-256 | `{sha(incoming)}` |', '',
    'The replay revalidated the complete 112-file committed driver closure and complete-tree execution request, all 105 committed native inputs, pinned build/dependency/toolchain predicates, actual Windows DLL and Rapier bytes, and both complete original engine archives. Both engine GUI/console PE roles, dependency closure, source patches, API evidence and proof identities passed their unchanged readers. Runtime custody uses the separately identified read-only Windows target derivation; it does not execute Windows binaries on the replay host.', '',
    'The captured application and execution driver are deliberately different. The source-locked new-execution derivation changes only their registered identity join and adds the exact retained runtime/build gates. The original same-head qualifiers and every frozen physical predicate remain unchanged. All observers are hashed from the actual new driver.', '',
    '## Correctness and negative controls', '',
    'The retained original engine passed the finite Safe font control and reproduced the exact expected `CowData<unsigned char>::get` index-zero/size-zero failure under Separate. That failed control remains failed and is classified as an admissible historical negative. No unrelated diagnostic is accepted as that failure.', '',
    f'The repaired engine passed both Safe and Separate font arms. All three successful finite font reads matched framebuffer SHA-256 `{report["font_and_startup"]["font_comparison"]["framebuffer_sha256"]}`. Each successful font arm executed the registered 64 draws and 6,016 glyph calls with the exact fixture and source. Both repaired ordinary Workbench startup owners passed, with native tick zero: these paused startup receipts carry no physical-progress credit.', '',
    'Both repaired render owners then passed the original two-slot transition tape: 180 actual admissions, 35 independently reconstructed initial/warmup/sparse-entry/final byte hashes per owner, and two fixed positive texture RIDs alternating without replacement or aliasing. The complete source/driver/render-owner/process/log joins and first-read current/previous histories were replayed from raw files before examining timing.', '',
    '## Physical decision', '',
    'Each table row uses exactly the first 144 genuine completed steps and 143 consecutive completion gaps. The same repaired executable, c2 application/native/Rapier, Full2, Early/coherent policy, deadline-off, continuation-off, full physical observer and submitted-pose/CPU observer are fixed. The order is Safe / Separate / Separate / Safe. Actual body trajectories, native responses, terrain revisions, input leases and Water ledgers satisfy the full unchanged physical gates and equal-step parity.', '',
    'The host was **AMD EPYC 9V74, four logical processors**, using ANGLE D3D11 with the **Microsoft Basic Render Driver**. It is not a physical NVIDIA result. Percentiles use the frozen linear-interpolated definition. Thresholds below are pre-existing reporting categories, not newly invented owner acceptance budgets.', '',
]
for case in report['cases']:
    title = 'Wave512 reference: one Wave round, spill disabled' if case['case'] == 'wave_512_follow' \
        else 'Current Wave2048: two Wave rounds, spill/ballistic enabled'
    lines += ['### ' + title, '',
              '| Arm | Actual steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 / >1000 ms |',
              '|---|---:|---:|---:|---:|---:|---|']
    for arm in case['arms']:
        w = arm['windows']['first_144_steps'];g = w['physical_gap_ms']
        counts = ' / '.join(str(w['gaps_above_ms'][str(v)]) for v in (100, 250, 500, 1000))
        lines.append(f'| {arm["index"]}: {arm["render_thread"]} | {fixed(w["rapier_steps_per_second"],6)} | {fixed(g["p50"])} | {fixed(g["p95"])} | {fixed(g["p99"])} | {fixed(g["max"])} | {counts} |')
    safe = [a['windows']['first_144_steps']['rapier_steps_per_second'] for a in case['arms'] if a['render_thread'] == 'safe']
    separate = [a['windows']['first_144_steps']['rapier_steps_per_second'] for a in case['arms'] if a['render_thread'] == 'separate']
    drops = [100 * (1 - c / d) for c in separate for d in safe]
    lines += ['', f'Both Separate rates are below both Safe controls: **{min(drops):.1f}–{max(drops):.1f}% lower** across the four cross-arm comparisons. The original registered improvement decision remains **NOT_ESTABLISHED**. This is a bounded adverse cohort, not a universal hardware theorem.', '']
lines += [
    'The first Safe512 arm includes its full 694.478 ms stall; it was not removed to improve the control. Separate512 happens to have smaller maximum gaps than that one outlier, while doubling the count of >100 ms gaps and losing 41–47% of progression. A favorable isolated maximum does not select the treatment. In the large workload, both Separate arms exceed one second, each with two >1000 ms gaps; both Safe controls remain below one second but still have severe tails.', '',
    '## Freshness and costs', '',
    '| Workload / arm | Upload-call mean ms | First-part completion age p95 / max ms | Material generation age at submission p95 / max ms | Actual first-144 submissions |',
    '|---|---:|---|---|---:|',
]
for case in report['cases']:
    for arm in case['arms']:
        w = arm['windows']['first_144_steps'];pr = arm['observers']['presentation']['windows']['first_144_steps']
        age = pr['selected_completion_age_ms'];mat = pr['material_generation_age_at_submission_ms']
        lines.append(f'| {"512" if case["case"]=="wave_512_follow" else "2048"} / {arm["index"]} {arm["render_thread"]} | {fixed(w["upload_submit_call_ms"]["mean"])} | {fixed(age["p95"])} / {fixed(age["max"])} | {fixed(mat["p95"])} / {fixed(mat["max"])} | {pr["submissions"]} |')
lines += ['',
    'All eight first-144 traces have zero withheld actors, zero intentional holds and zero selected physical steps behind. Those counters coexist with material ages above one second and first-part selected-completion ages up to 1.085 seconds. The independent pose joins use real completion times and the actual submitted first collider part/transform; geometry verification does not turn an old wall-clock pose into a fresh one. One to three pre-capture/initial poses per arm lack an independent in-capture completion time and remain explicitly unknown.', '',
    'For Safe, submitted state can be joined to its inline completion notification. For Separate, the callback is a Main-delivered draw-completion notification. It does not identify the rendering owner’s exact completion time, the GPU, scanout or which material serial was displayed. The reducer requires that Separate draw/material association remain unavailable. Submitted state is still observed independently at Main’s actual pre-draw boundary.', '',
    '| Workload / arm | Sampled process interval s | Process user + kernel CPU s | Mean CPU cores | Queried peak RSS MiB | Pose observer total ms |',
    '|---|---:|---:|---:|---:|---:|',
]
for row in resources['arms']:
    cpu = row['cpu']
    lines.append(f'| {"512" if row["case"]=="wave_512_follow" else "2048"} / {row["index"]} {row["render_thread"]} | {fixed(cpu["observed_interval_seconds"])} | {fixed(cpu["observed_user_seconds"]+cpu["observed_kernel_seconds"])} | {fixed(cpu["mean_cpu_core_equivalents"])} | {fixed(row["maximum_queried_kernel_peak_rss_bytes"]/1048576,1)} | {fixed(row["presentation_observer_total_usec"]/1000)} |')
lines += ['',
    'These are actual process-wide user/kernel counters and kernel peak-RSS queries, independently bound to each owned Godot PID. They include setup and cleanup and are not aligned to the 11–42 second physics capture. They cannot establish CPU cost per completed physics step. The independently retained instantaneous-RSS maxima are distinct from the maximum queried kernel peak. The external sampler reports its own read time, including successful and failed queries; its largest reads here are about 201–244 ms. That external wall cost is not Godot CPU and is not silently charged to a specific physics step.', '',
    'The extra pose observer was enabled identically in all matched arms. Its measured total callback work is retained, and different owner/callback counts naturally change that total. This experiment supplies no new off/on calibration for this repaired Windows engine; earlier Linux calibration is not inherited as a zero-overhead claim.', '',
    '## Architectural consequence and limits', '',
    'Separate makes the CPU upload submission call dramatically faster: roughly 98–104 ms means become 0.44–0.49 ms for512, and 119–140 ms become 1.68–1.90 ms for2048. Actual completed physics gets slower and submitted material/pose ages worsen. The effect is therefore insufficient as a playability repair. This reinforces the retained Target-publication negative: moving or shortening a submission call does not establish reduced end-to-end dependency or rendering backpressure.', '',
    'The finite font race is independently repaired for the tested engine/ANGLE cases. Its ownership fix may remain as a correctness candidate. It does not select Separate rendering. A next scheduling/engine arm needs an explicit different blocked-stage hypothesis and unchanged native/terrain/physical authority; these results do not justify another undifferentiated Separate or faster-upload campaign.', '',
    'Actual native start/wake/dispatch clocks were not enabled in these timing arms. The separately reported native-completion→physical clocks show delay after native completion, but elapsed solver calls and publication overlaps are not pure CPU/GPU execution. No missing native start is synthesized by subtracting a duration. No specific physical NVIDIA driver cause can be inferred from hosted software rendering.', '',
    'The cohorts contain one controlled actor and the registered Follow tape, not sustained eight-actor painting. They neither repair nor invalidate the separately reproduced submerged-actor withholding defect. Ordinary mixed workloads, long-duration freshness, input-device-to-display latency, actual display trails, default Windows WGL and physical NVIDIA remain explicit acceptance work. The successful workflow is an evidence/qualification success containing a negative performance decision; it is not a production or playability pass.', '',
    '## Reproduction', '',
    'The [complete replay](focused-font/independent-replay.json), [executed reader](focused-font/replay.py), [resource readouts](focused-font/resource-readouts.json) and [packet builder](focused-font/build_packet.py) are indexed with exact hashes in [INDEX.json](focused-font/INDEX.json). Original ZIPs and raw process/trace files remain authoritative. The complete report retains every physical window, supplementary observation and relative-decision predicate.', '',
    'The executed reader accepts `--workspace-root` and `--output`. It expects an isolated detached Git checkout at `evidence-c/font-reader-root`, with HEAD exactly `d4f4afe93d02192d9165622b78b762d9fbf8dc3e`, and the retained files at the documented paths. Only the `tools`, `third_party`, `godot/tests`, `.github`, palette selector and material shader source paths need checkout; committed application/native input objects remain available through Git. Use `GIT_LFS_SKIP_SMUDGE=1` for this source reconstruction so inactive-platform pointer bytes match the original capture.', '',
    'The reader restores original engine archives into temporary bounded directories, fully verifies them, retires the old restored payload after admission, and removes the repaired temporary runtime at exit. Each timed arm is extracted and reconstructed separately. It calls only read-only retained-data validators; it never launches an engine or reruns gameplay. A missing source/runtime byte fails the replay rather than weakening custody.', '',
]
(audit / 'focused-font-decision.md').write_text('\n'.join(lines))
index = {'schema': 'pubpres-focused-font-peer-packet-v1', 'archive_sha256': report['archive_sha256'],
         'files': {path.name: {'bytes': path.stat().st_size, 'sha256': sha(path)} for path in sorted(packet.iterdir())
                   if path.is_file() and path.name != 'INDEX.json'},
         'decision': {'path': '../focused-font-decision.md', 'sha256': sha(audit / 'focused-font-decision.md')},
         'physical_acceptance': 'HOLD'}
(packet / 'INDEX.json').write_text(json.dumps(index, indent=2) + '\n')
print(json.dumps({'packet': str(packet), 'index_sha256': sha(packet / 'INDEX.json'),
                  'decision_sha256': sha(audit / 'focused-font-decision.md'), 'files': len(index['files'])}))
