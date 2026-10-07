# Native PowerShell counterpart of oh-my-zsh/scripts/cache-clean.sh.
# Invoke as a script (not dot-sourced), so exit codes stay local to this invocation.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$defaults = @('uv', 'pip', 'bun', 'npm', 'pnpm', 'yarn', 'cargo', 'go', 'conda', 'mamba', 'micromamba', 'pixi', 'brew', 'deno', 'mise', 'ccache', 'composer', 'dotnet')
$all = $defaults + 'docker'
$mode = 'clean'
$targets = [Collections.Generic.List[string]]::new()
foreach ($argument in $args) {
    switch -CaseSensitive ($argument) {
        { $_ -in '-h', '--help' } {
            Write-Output 'Usage: cache-clean [--list | --dry-run] [TARGET ...]'
            Write-Output "Targets: $($all -join ', ')"
            Write-Output 'Missing tools are skipped. Docker is explicit-only; its current builder may be remote.'
            Write-Output 'Brew cleanup also removes old versions. Go removes downloaded modules as well.'
            exit 0
        }
        { $_ -in '-n', '--dry-run' } { $mode = 'dry-run'; break }
        { $_ -in '-l', '--list' } { $mode = 'list'; break }
        default {
            if ($_ -cnotin $all) {
                Write-Host "Unknown target or option: $_" -ForegroundColor Red
                exit 2
            }
            if (-not $targets.Contains($_)) { $targets.Add($_) }
        }
    }
}
if ($targets.Count -eq 0) {
    $targets.AddRange([string[]]$(if ($mode -eq 'list') { $all } else { $defaults }))
}
$commands = @{
    uv = @('cache', 'clean')
    pip = @('cache', 'purge')
    bun = @('pm', 'cache', 'rm')
    npm = @('cache', 'clean', '--force')
    pnpm = @('store', 'prune')
    yarn = @('cache', 'clean')
    cargo = @('cache', '--remove-dir', 'all')
    go = @('clean', '-cache', '-testcache', '-modcache', '-fuzzcache')
    conda = @('clean', '--tarballs', '--index-cache', '--yes')
    mamba = @('clean', '--tarballs', '--index-cache', '--yes')
    micromamba = @('clean', '--tarballs', '--index-cache', '--yes')
    pixi = @('clean', 'cache', '--yes')
    brew = @('cleanup', '--prune=all', '--scrub')
    deno = @('clean')
    mise = @('cache', 'clear')
    ccache = @('--clear')
    composer = @('--no-interaction', '--no-plugins', '--no-scripts', 'clear-cache')
    dotnet = @('nuget', 'locals', 'all', '--clear')
    docker = @('builder', 'prune', '--all', '--force')
}
$succeeded = 0
$skipped = 0
$failed = 0
foreach ($target in $targets) {
    $program = Get-Command $target -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $program -and $target -eq 'pip') {
        $program = Get-Command pip3 -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $program) {
        Write-Host "[skip] $target (not installed)"
        $skipped++
        continue
    }
    if ($target -eq 'cargo' -and -not (Get-Command cargo-cache -ErrorAction SilentlyContinue)) {
        Write-Host '[skip] cargo (install helper with: cargo install cargo-cache)'
        $skipped++
        continue
    }
    $commandArgs = $commands[$target]
    $scratch = $null
    $pushed = $false
    try {
        if ($target -eq 'yarn') {
            $global:LASTEXITCODE = 0
            $version = (& $program --version 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or $version -notmatch '^(\d+)\.') {
                Write-Host '[skip] yarn (could not determine version)'
                $skipped++
                continue
            }
            if ([int]$Matches[1] -ge 2) { $commandArgs += '--mirror' }
        }
        $label = if ($mode -eq 'list') { 'available' } else { $mode }
        $note = if ($target -eq 'bun') { ' (in a temporary empty package)' } elseif ($target -eq 'docker') { ' (explicit only)' } else { '' }
        Write-Host "[$label] $($program.Name) $($commandArgs -join ' ')$note"
        if ($mode -eq 'clean') {
            if ($target -eq 'bun') {
                $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
                $scratch = Join-Path $tempRoot ('cache-clean-' + [guid]::NewGuid().ToString('N'))
                $null = New-Item -ItemType Directory -Path $scratch
                Set-Content -LiteralPath (Join-Path $scratch 'package.json') -Value '{}' -Encoding ascii
                Push-Location -LiteralPath $scratch
                $pushed = $true
            }
            $global:LASTEXITCODE = 0
            & $program @commandArgs | Out-Host
            if ($LASTEXITCODE -in 130, 143, -1073741510) { exit $LASTEXITCODE }
            if ($LASTEXITCODE -ne 0) { throw "$target exited with code $LASTEXITCODE" }
        }
        $succeeded++
    }
    catch {
        Write-Host "[failed] ${target}: $_" -ForegroundColor Red
        $failed++
    }
    finally {
        if ($pushed) { Pop-Location }
        if ($scratch -and (Test-Path -LiteralPath $scratch)) {
            # Only remove the uniquely named directory created by this invocation.
            $item = Get-Item -LiteralPath $scratch -Force
            if ($item.Parent.FullName.TrimEnd('\', '/') -ne $tempRoot.TrimEnd('\', '/') -or
                $item.Name -notmatch '^cache-clean-[0-9a-f]{32}$' -or
                ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "Refusing to remove unexpected scratch directory: $scratch"
            }
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
        }
    }
}
if ($mode -eq 'clean') {
    Write-Host "Done: $succeeded succeeded, $skipped skipped, $failed failed."
} else {
    Write-Host "Preview: $succeeded available, $skipped skipped, $failed failed. No cleanup commands ran."
}
if ($failed) { exit 1 }
exit 0
