# Run from Unity project root: powershell -ExecutionPolicy Bypass -File Unity-Skills\install.ps1
#Requires -Version 5.0
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDir = Join-Path $ScriptDir "skills"
$TargetDir = Join-Path (Get-Location).Path ".claude\skills"

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

$linked = 0
Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
    $skillName = $_.Name
    $target = Join-Path $TargetDir $skillName

    if (Test-Path -LiteralPath $target) {
        $existing = Get-Item -LiteralPath $target -Force
        if ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            # Removes just the junction point -- does not touch the linked source folder.
            cmd /c rmdir "$target" | Out-Null
        } else {
            Write-Warning "  Skipped: $skillName (a real folder already exists at $target -- remove it manually first)"
            return
        }
    }

    New-Item -ItemType Junction -Path $target -Target $_.FullName | Out-Null
    Write-Host "  Linked: $skillName"
    $linked++
}

Write-Host ""
Write-Host "Done - $linked skills available as /u-* in Claude Code."
Write-Host "If Claude Code is already running, skills activate immediately (no restart needed)."

# Agents: one hard link per agent file (file symlinks need admin on Windows; hard links do not).
# Re-run after pulling agent changes. Definitions load at session start, so restart Claude Code.
$AgentsDir = Join-Path $ScriptDir "agents"
if (Test-Path -LiteralPath $AgentsDir) {
    $AgentsTarget = Join-Path (Get-Location).Path ".claude\agents"
    New-Item -ItemType Directory -Force -Path $AgentsTarget | Out-Null
    Get-ChildItem -Path $AgentsDir -Filter *.md | ForEach-Object {
        $link = Join-Path $AgentsTarget $_.Name
        if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
        New-Item -ItemType HardLink -Path $link -Target $_.FullName | Out-Null
    }
    Write-Host "  Linked: agents (restart Claude Code to load them)"
}
