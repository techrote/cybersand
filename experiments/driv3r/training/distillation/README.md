# DRIV3R — D-STUDENT-001 real d1 anchor / synthetic-game distillation

**Research Draft/HOLD only. No game code, Workbench, native engine, production provider or default is changed.** Student checkpoint files stay in immutable GitHub Actions artifacts, never Git history.

## What is genuinely sourced

`prepare_corpus.py` validates two independently archived **real d1-2B Q8 System One Frankenlayer inference** artifacts, with exact ZIP SHA-256, original parent observation, raw selected action and per-action probability. The 144 original calls comprise **48 stock**, **48 GREYHOUND** and **48 BRANCHWITCH** decisions. All original parent calls used **source seed 570** and three closely overlapping observation families; there is NO independent parent generalization result.

- GREYHOUND + stock: [original Actions artifact 14181164165](https://github.com/techrote/cybersand/actions/runs/43764117645/artifacts/14181164165); ZIP SHA `e4bf6b63997967cb0ccc1b4a34e517c7abb62a79d5dc8069e93b9a02371ecff3`.
- BRANCHWITCH: [original Actions artifact 14182441899](https://github.com/techrote/cybersand/actions/runs/43764117645/artifacts/14182441899); ZIP SHA `0ca2cf83eca44e3462a29ba0a27ae41e62d342bb8a4224f677539a26b68bc181`.
- Deterministic extracted original-teacher JSONL SHA `140342c16a0b8c6c8d2c3bc6071767885b15096d5a53bbf304979f3015c86522`; source schema `cybersand.driv3r.distill.original-teacher/1`.

**The parent is NOT run on any new synthetic situation.** Original parent distributions are probability anchors for deliberately synthesized, obstacle-conditional policies. `aerohound_proxy` is a named *synthetic oscillation approximation*, NOT an observed/checked AEROHOUND model.

## Actual student training and comparisons

External CPU-only, 24×24 obstacle/protected/painted-cell host uses six W0-like actions: STRAIGHT, LEFT, RIGHT, BRANCH, RETRACE, STOP. The *external simulator does not reproduce native W0 execution*. The student is a ~5,142-parameter float32 100→48→6 tanh MLP, genuinely trained with 450 Adam optimizer updates against a soft-label teacher mixture. Train obstacle seeds 1–64, validation 1001–1016, final worlds 2001–2016. The synthetic states/trajectories are not genuine parent inference, and synthetic structural decisions do not replace real student-vs-parent replay.

One 450-step local CPU preflight: 5,519 synthetic train examples; held-out synthetic teacher top-1 agreement 84.7%, held-out soft-target cross-entropy 1.092 versus raw untrained 1.826. (Training seed and optimizer order are explicitly reproducible; the hosted source HEAD must be separately qualified.) Matched final 40-turn synthetic test: 16 obstacle worlds × four styles × six controllers = 384 world-controller episodes. Trained student averages 32.09 unique cells and 17.19 branches. **Flat legal random including STOP** quits after 5.11 turns on average and is an inappropriate coverage comparator; **flat legal with optional STOP excluded** averages 23.09 cells and 8.22 branches, while fidget averages 30.94 cells and 5.75 branches. These are illustrative synthetic trajectories, not proof of useful real CyberSand steering.

The report preserves voluntary STOP rate, model-vs-untrained controller, host-invalid actions, visits, retraces, repetition, and original gallery PNGs. The student's deliberately branch-heavy outputs often make crowded blobs; subjective amusement and held-out teacher CE are distinct.

## Reproduction

```sh
python3 -m pip install numpy pillow
python3 -m experiments.driv3r.training.distillation.prepare_corpus GREYHOUND.zip BRANCHWITCH.zip original_teachers.jsonl
export DRIV3R_TEACHER_CORPUS="$PWD/original_teachers.jsonl"
OPENBLAS_NUM_THREADS=1 python3 -m unittest discover -s experiments/driv3r/training/distillation -p 'test_*.py' -v
OPENBLAS_NUM_THREADS=1 python3 -m experiments.driv3r.training.distillation.lab --out ./evidence-student --steps 450
```

Source-only files live under this path; the dedicated `driv3r-game-distillation-curriculum.yml` GitHub Actions workflow retrieves/verifies immutable parent artifacts, trains a new student, records `student.npz`, `metrics.json`, `rollouts.jsonl`, gallery PNG, original teacher JSONL, source-HEAD identity and artifact SHA256SUMS. No paid API, GPU or native authoring. **Do not promote a faithful-parent or trained-model freeze:** original 16-turn parent evidence shares one seed; new source-pinned parent episodes in obstacle-adverse worlds, 64–128 turn W0 closed loop, and real expressive-recovery comparisons remain the next falsification gate.
