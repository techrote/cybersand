# CyberSand: temporary interactive Windows acceptance via GitHub Actions

**Status:** implementation candidate, Draft/HOLD. No Windows desktop was provisioned
or tested by creating this document. Before any merge, the owner must review the
security model and explicitly authorize activation. Because the manual Actions UI
requires the workflow on the default branch, the first live RDP trial ordinarily
happens **after** an owner-authorized infrastructure merge. Do not call it
qualified or production-ready until that trial succeeds.

## Purpose

The manual-only `.github/workflows/windows-acceptance-desktop.yml` deploys a
**Windows Server 2022** VM for a bounded human acceptance pass. It **does not**
run a nested Windows VM in Codespaces and **does not** provision a general-purpose
desktop. It consumes an already-produced Windows evaluator from a completed
successful **same-repository** Actions run, checks the run's source SHA, requires
a single package with `review-manifest.json`, verifies the Godot binary and
all LFS runtime digests in that manifest, then creates a desktop launcher.
Existing `tools/package_workbench_review.py` emits that form of manifest and
`Open Workbench.cmd`.

It provides an **RDP** session over a private Tailscale network rather than VNC.
The RDP account is non-administrator, has read/execute access to the evaluator
and write access to `C:\Acceptance\Feedback`. No public RDP firewall rule is
created. The service allows only IPv4 peers from `100.64.0.0/10` and Tailscale
access controls must be configured to restrict it to the owner's devices.

## One-time operator setup

1. Create a Tailscale tailnet or use an existing one. Install Tailscale on
   your Windows client. Restrict the tailnet ACL to permit only your user/device
   to reach tagged acceptance runners on TCP/3389. **Do not** use a broad
   public tunnel or port forwarding.
2. Generate an ephemeral, tagged, reusable, pre-approved (if approval is used)
   auth key in Tailscale; add it as the Actions repository secret
   `TAILSCALE_AUTHKEY`. Limit its validity and rotate it. Prefer a dedicated
   tailnet tag over granting the ephemeral runner access to other machines.
3. Set `ACCEPTANCE_RDP_PASSWORD` as a repository Actions secret to a strong
   value of **20 characters or more**, known only to the owner. Passwords are
   never emitted to Actions logs. The remote login name is `cybersand-accept`.
4. Review the Draft PR. The new manual workflow must be available on the
   repository default branch to appear with a **Run workflow** button in the
   GitHub Actions UI. It cannot be launched in this chat because the GitHub
   integration here exposes repository/Actions reads and writes but no
   interactive Windows RDP connection, tailnet identity or live desktop.
   **Owner controls merging/activation.** The Draft PR itself does not run an
   acceptance job, and its first hosted desktop cannot be validated here.

## Each acceptance pass

1. Ask an agent to prepare one source-matched portable Windows evaluator.
   It must include `Open Workbench.cmd`, `Godot.exe`, `review-manifest.json`,
   the `godot/` project and the materialized Git LFS runtimes. The existing
   `tools/package_workbench_review.py` is a compatible packaging entry point.
   Publish the package as **one** Actions artifact (direct directory or one ZIP).
2. Record the successful producer Actions run ID, exact artifact name and
   full 40-character source SHA from its provenance/manifest.
3. Open **Actions → CyberSand Windows acceptance desktop → Run workflow**.
   Enter the three values and select 30, 60, 120, 240 or 300 minutes.
   The run first validates the producer run (same repository, successful, source
   SHA match), package and original runtime, **before** authenticating Tailscale.
4. Inspect the new job's summary for its Tailscale `100.x.y.z` IP. From a
   Windows computer connected to the same tailnet, launch `mstsc` and connect
   to the given IP. Login as `cybersand-accept` using the password set in
   `ACCEPTANCE_RDP_PASSWORD`.
5. Open **CyberSand Workbench** on the remote desktop. Save optional PASS/FAIL
   notes or screenshots in `C:\Acceptance\Feedback`. The run uploads only that
   folder as a short-lived artifact. Cancel the workflow when finished.

The session ends automatically after the selected interval or immediately
when cancelled. Its VM contents are disposable; keep exported evidence in the
dedicated feedback folder before exit. A cancelled run may not upload feedback
reliably—download it manually during the session if it matters.

## Boundaries, risks and qualification

- Standard Windows hosted runners are Windows **Server**, not the owner's
  Windows 11 graphics stack, with no physical NVIDIA GPU/Vulkan device.
  RDP often supplies a software/virtual display. This can qualify layout,
  input, native Windows loading and qualitative non-GPU interactions; it is
  **not** a source of target-machine FPS, GPU publication, tearing or Vulkan
  driver acceptance.
- RDP can create a separate Windows session from the Actions runner service.
  Actions scripts must **not** be assumed to drive an interactive GUI after
  the remote login; the **human** launches and tests within RDP.
- A package with a source manifest is not a security audit. Only feed this
  workflow code built from **trusted owner-reviewed branches**. An executable
  received from another actor is potentially malicious; never combine
  untrusted code with tailnet credentials or broad tailnet reachability.
- Only `techrote` may dispatch in the provided workflow. The job uses
  `windows-2022`, GitHub-hosted runner routing, `contents:read` and
  `actions:read`, and has a 355-minute outer timeout. There are no automatic
  scheduled runs, paid model calls, or changes to the production game.
- Actions usage must remain tied to testing the repository's software. Treat
  it as a **disposable acceptance machine**, not an idle cloud workstation.
  Public-repository standard runner compute may be free under GitHub's
  current terms; verify your repository visibility/billing.
- Before acceptance: verify RDP login, correct desktop launcher, source SHA
  and LFS bytes, access-control isolation, port visibility, reconnection,
  bounded cancellation, feedback retention and appropriate test cases
  on **one fresh actual Windows hosted runner**. None of these have run yet.
- Independent Windows 11/physical GTX or RTX hardware acceptance remains
  essential for your renderer/presentation/performance defects.

Activation is not proof. Do not claim that RDP, feedback uploads or network
isolation succeeded until the owner runs and records a real test.

See https://docs.github.com/en/actions/reference/limits and
https://tailscale.com/docs/integrations/github/github-action .
