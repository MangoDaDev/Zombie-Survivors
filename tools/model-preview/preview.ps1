param(
    [Parameter(Position=0)][ValidateSet('render','validate','export','test')][string]$Command = 'render',
    [Parameter(Position=1)][string]$InputFile = '-',
    [string]$Out = '',
    [string]$Settings = '',
    [string]$Views = '',
    [ValidateSet('orthographic','perspective')][string]$Projection,
    [string]$Resolution = '',
    [switch]$Transparent,
    [int]$Samples = 0,
    [switch]$Paste,
    [switch]$Clipboard,
    [switch]$RenderTests,
    [string]$Blender = ''
)
$ErrorActionPreference = 'Stop'
if ($Paste -or $Clipboard) { $InputFile = '-' }
if (-not $Blender) {
    $Blender = $env:MODEL_PREVIEW_BLENDER
}
if (-not $Blender) {
    $Blender = Join-Path $env:ProgramFiles 'Blender Foundation/Blender 4.5/blender.exe'
}
if (-not (Test-Path -LiteralPath $Blender)) { throw "Blender not found: $Blender. Pass -Blender or set MODEL_PREVIEW_BLENDER." }
$arguments = @('--background','--factory-startup','--disable-autoexec','--threads','1','--python-exit-code','1','--python',(Join-Path $PSScriptRoot 'cli.py'),'--',$Command)
if ($Command -ne 'test') { $arguments += $InputFile }
if ($Out) { $arguments += @('--out', $Out) }
if ($Settings) { $arguments += @('--settings', $Settings) }
if ($Views) { $arguments += @('--views', $Views) }
if ($Projection) { $arguments += @('--projection', $Projection) }
if ($Resolution) { $arguments += @('--resolution', $Resolution) }
if ($Transparent) { $arguments += '--transparent' }
if ($PSBoundParameters.ContainsKey('Samples')) { $arguments += @('--samples', [string]$Samples) }
if ($RenderTests) { $arguments += '--render-tests' }
$previousResources = $env:BLENDER_USER_RESOURCES
$previousEncoding = $OutputEncoding
try {
    # Keep Blender's extension/config caches local; factory-startup must not touch
    # the user's installed extensions or normal Blender preferences.
    $env:BLENDER_USER_RESOURCES = Join-Path $PSScriptRoot '.work/blender'
    New-Item -ItemType Directory -Force -Path $env:BLENDER_USER_RESOURCES | Out-Null
    $OutputEncoding = New-Object System.Text.UTF8Encoding $false
    if ($Clipboard) {
        # Reading the clipboard is opt-in. Send UTF-8 so instance names survive
        # Windows PowerShell's otherwise lossy default native-pipeline encoding.
        Get-Clipboard -Raw | & $Blender @arguments | ForEach-Object { if ($_ -notmatch '^(Fra:|Time:|Saved:)') { $_ } }
    } else {
        & $Blender @arguments | ForEach-Object { if ($_ -notmatch '^(Fra:|Time:|Saved:)') { $_ } }
    }
    $renderExitCode = $LASTEXITCODE
} finally {
    $env:BLENDER_USER_RESOURCES = $previousResources
    $OutputEncoding = $previousEncoding
}
exit $renderExitCode
