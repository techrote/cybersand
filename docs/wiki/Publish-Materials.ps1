# Publish the source-verified CyberSand materials catalogue to the real GitHub Wiki.
# Requires: Git with an authenticated GitHub credential. Does not modify the
# source repository. By default refuses to replace an existing Materials.md.
param([switch] $AllowOverwrite)

$ErrorActionPreference = 'Stop'
$wikiRemote = 'https://github.com/techrote/cybersand.wiki.git'
$sourceUrl = 'https://raw.githubusercontent.com/techrote/cybersand/1ca66809fab4b86475b0a1f2464f20aca6e68e1d/docs/wiki/Materials.md'
$tempWiki = Join-Path ([System.IO.Path]::GetTempPath()) ('cybersand-wiki-' + [guid]::NewGuid().ToString('N'))

try {
    & git clone --quiet $wikiRemote $tempWiki
    if ($LASTEXITCODE -ne 0) {
        throw 'Wiki clone failed. If the Wiki was only just enabled, create and save its initial Home page on GitHub before trying again. Otherwise check your GitHub Git authentication.'
    }

    $target = Join-Path $tempWiki 'Materials.md'
    if ((Test-Path -LiteralPath $target) -and -not $AllowOverwrite) {
        throw 'The Wiki already has Materials.md. No changes were made. Review it before deciding whether to rerun with -AllowOverwrite.'
    }

    Invoke-WebRequest -Uri $sourceUrl -OutFile $target
    if ((Get-Item -LiteralPath $target).Length -lt 40000) {
        throw 'Downloaded Markdown is unexpectedly short. Publication refused.'
    }

    $wikiBranch = (& git -C $tempWiki symbolic-ref --quiet --short HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wikiBranch)) {
        throw 'Cannot determine the Wiki default branch. Publication refused.'
    }

    & git -C $tempWiki add -- Materials.md
    if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
    & git -C $tempWiki diff --cached --quiet -- Materials.md
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Wiki Materials.md is already identical; no push needed.'
        return
    }
    if ($LASTEXITCODE -ne 1) { throw 'git diff failed' }

    # Fixed to the authenticated techrote account's public GitHub noreply identity.
    # This avoids requiring machine-wide Git user.name/user.email configuration.
    & git -C $tempWiki -c 'user.name=techrote' -c 'user.email=261801702+techrote@users.noreply.github.com' commit -m 'docs(wiki): add source-exact Materials reference'
    if ($LASTEXITCODE -ne 0) { throw 'Wiki commit failed' }

    & git -C $tempWiki push origin ("HEAD:refs/heads/" + $wikiBranch)
    if ($LASTEXITCODE -ne 0) { throw 'Wiki push failed; no successful publication confirmed' }

    Write-Host 'Published: https://github.com/techrote/cybersand/wiki/Materials'
}
finally {
    if (Test-Path -LiteralPath $tempWiki) {
        Remove-Item -LiteralPath $tempWiki -Recurse -Force
    }
}
