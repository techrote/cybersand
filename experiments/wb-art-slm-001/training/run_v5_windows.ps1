# First real v5 LoRA candidate on an owner-controlled Windows CPU machine.
# No paid API, external task, Git writes, old adapter overwrite or hidden retries.
# Example:
#   & .\run_v5_windows.ps1 -CorpusZip 'C:\Downloads\wb_art_slm_001_executed_corpus.zip' -Python 'C:\wb-art-slm-private\venv\Scripts\python.exe'
# Run from integrated Draft #567 (it contains the independently owned Corpus v5 manifest).
# For a true checkpoint continuation, specify -Resume <exact checkpoint> and NEW -CandidateName.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CorpusZip,
  [string]$Python = 'python',
  [string]$PrivateRoot = 'C:\wb-art-slm-private',
  [string]$CandidateName = 'lfm350-v5-contrast-400',
  [string]$ModelDir = '',
  [string]$V5Manifest = '',
  [string]$Resume = '',
  [switch]$DownloadPinnedBase
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$trainingDir = $PSScriptRoot
$expDir = (Resolve-Path (Join-Path $trainingDir '..')).Path
$compiler = Join-Path $expDir 'controls\pattern_compiler.py'
$manifest = if ($V5Manifest) { $V5Manifest } else { Join-Path $expDir 'corpus\failure_contrast_replay_v5.json' }
$root = [IO.Path]::GetFullPath($PrivateRoot)
$corpusZipFull = (Resolve-Path $CorpusZip).Path
if (-not $ModelDir) { $ModelDir = Join-Path $root 'models\lfm350' }
$modelDirFull = [IO.Path]::GetFullPath($ModelDir)
$v5Full = (Resolve-Path $manifest).Path
$compilerFull = (Resolve-Path $compiler).Path
if ($CandidateName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{2,70}$') {
  throw 'CandidateName must be a safe new run directory name.'
}
if (-not (Test-Path -LiteralPath $Python -PathType Leaf) -and -not (Get-Command $Python -ErrorAction SilentlyContinue)) {
  throw "Python not found: $Python. Use a pinned Python 3.12 environment."
}
& $Python -c 'import sys,torch,transformers,peft,filelock,safetensors; assert sys.version_info[:2] == (3,12), sys.version'
if ($LASTEXITCODE -ne 0) {
  throw 'Pinned Python 3.12 + torch/transformers/peft/filelock/safetensors runtime missing. Install training/requirements.lock into a private venv first.'
}
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $corpusZipFull).Hash.ToLowerInvariant()
if ($zipHash -ne '2d2de250731eeea825339e89f752ab8ebc65f3a929daa2c692120d985566948a') {
  throw "Executed corpus ZIP checksum differs from the original admitted archive: $zipHash"
}
New-Item -ItemType Directory -Path $root -Force | Out-Null
$corpusExtraction = Join-Path $root 'corpus-original'
if (-not (Test-Path -LiteralPath $corpusExtraction -PathType Container)) {
  New-Item -ItemType Directory -Path $corpusExtraction -Force | Out-Null
  Expand-Archive -LiteralPath $corpusZipFull -DestinationPath $corpusExtraction
}
$corpus = Join-Path $corpusExtraction 'corpus'
$train = (Resolve-Path (Join-Path $corpus 'train.jsonl')).Path
$dev = (Resolve-Path (Join-Path $corpus 'dev.jsonl')).Path
$admission = (Resolve-Path (Join-Path $corpus 'admission.json')).Path
$corpusManifest = (Resolve-Path (Join-Path $corpus 'manifest.json')).Path
$trainHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $train).Hash.ToLowerInvariant()
if ($trainHash -ne '972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66') {
  throw "TRAIN original-source checksum mismatch: $trainHash"
}
# The trainer pins the complete original native admission, compiler, model receipt,
# v5 400-index manifest and optimizer/RNG state. FINAL is not read.
if (-not (Test-Path -LiteralPath $modelDirFull -PathType Container)) {
  if (-not $DownloadPinnedBase) {
    throw "Pinned LFM350 base is absent: $modelDirFull. Supply -DownloadPinnedBase only on an authorized Internet-connected local machine."
  }
  New-Item -ItemType Directory -Path (Split-Path -Parent $modelDirFull) -Force | Out-Null
  & $Python (Join-Path $trainingDir 'download_model.py') --profile lfm2_5_350m --output $modelDirFull
  if ($LASTEXITCODE -ne 0) { throw 'Official pinned base-model download failed.' }
}
$receiptInside = Join-Path $modelDirFull 'download_receipt.json'
$receiptAbove = Join-Path (Split-Path -Parent $modelDirFull) 'download_receipt.json'
if (-not (Test-Path $receiptInside) -and -not (Test-Path $receiptAbove)) {
  throw 'The pinned base-model snapshot has no download_receipt.json. Refusing unverified base.'
}
$runParent = Join-Path $root 'runs'
New-Item -ItemType Directory -Path $runParent -Force | Out-Null
$output = Join-Path $runParent $CandidateName
if (Test-Path $output) { throw "Output already exists: $output; choose a new -CandidateName, never overwrite a candidate." }
$trainerArgs = @(
  (Join-Path $trainingDir 'job_guard.py'),
  '--run-parent', $runParent,
  '--wall-seconds', '3300',
  '--save-margin-seconds', '300',
  '--',
  '--train', $train,
  '--dev', $dev,
  '--admission', $admission,
  '--corpus-manifest', $corpusManifest,
  '--compiler', $compilerFull,
  '--v5-manifest', $v5Full,
  '--model', $modelDirFull,
  '--model-id', 'LiquidAI/LFM2.5-350M',
  '--revision', '9921cd4d82c0e3986887aa4b376f9446729ef8a3',
  '--output', $output,
  '--curriculum', 'failure-contrast-v5',
  '--steps', '400',
  '--seed', '731',
  '--checkpoint-every', '25',
  '--max-seconds', '1950',
  '--skip-baseline', '--skip-final-eval',
  '--threads', '3', '--device', 'cpu'
)
if ($Resume) {
  $resolvedResume = (Resolve-Path $Resume).Path
  $trainerArgs += @('--resume', $resolvedResume)
}
Write-Host "Starting ONE fresh/resumed bounded CPU candidate: $output"
Write-Host "Trainer: $trainingDir; pinned corpus ZIP SHA: $zipHash; v5 manifest: $v5Full"
& $Python @trainerArgs
$exitCode = $LASTEXITCODE
$result = Join-Path $output 'guard_result.json'
if (Test-Path $result) { Get-Content -Raw $result }
if ($exitCode -ne 0) {
  throw "Training supervisor exit $exitCode. Preserve $output and durable lease; inspect latest_checkpoint.json before a fresh resume output name."
}
Write-Host "Training supervisor completed: $output. Verify checkpoint identity and run untouched 24 DEV / 12 literal first-pass evaluation next."
