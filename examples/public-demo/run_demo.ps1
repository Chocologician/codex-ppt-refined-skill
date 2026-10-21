<# 在安装桌面 PowerPoint 的 Windows 上重放公开演示，不调用图片接口。 #>
[CmdletBinding()]
param([string]$OutputDirectory=(Join-Path (Get-Location) ('.build/public-demo-'+[guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).ProviderPath
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw '输出目录已存在，请选择一个新目录，避免覆盖既有文件。'}
[void][IO.Directory]::CreateDirectory($output)
$source=Join-Path $PSScriptRoot 'source.pptx'
$before=(Get-FileHash -LiteralPath $source).Hash
& (Join-Path $repo 'skills/codex-ppt/scripts/apply_refined_animations.ps1') -Mode apply -SourcePath $source -PlanPath (Join-Path $PSScriptRoot 'animation-plan.json') -OutputPath (Join-Path $output 'animated.pptx') -ReportPath (Join-Path $output 'audit.json')
if((Get-FileHash -LiteralPath $source).Hash -ne $before){throw '源文件发生变化。'}
Write-Output ('演示已生成：'+(Join-Path $output 'animated.pptx'))
Write-Output '请用桌面 PowerPoint 打开并按 F5 放映，页内自动展开，讲完单击翻页。'
