<# Windows + desktop Microsoft PowerPoint. Produces a candidate, not a final validated deliverable. #>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('inspect','apply')][string]$Mode,
 [Parameter(Mandatory)][string]$SourcePath,
 [Parameter(Mandatory)][string]$ReportPath,
 [string]$PlanPath,
 [string]$OutputPath,
 [switch]$ReplaceExisting
)
$ErrorActionPreference='Stop'
function Get-ShapeRecord($shape,[bool]$topLevel) {
 $summary=''
 $children=@()
 if($shape.HasTextFrame -and $shape.TextFrame.HasText){$summary=$shape.TextFrame.TextRange.Text}
 if($shape.Type -eq 6){
  foreach($child in $shape.GroupItems){$children+=Get-ShapeRecord $child $false}
  $summary=($children | ForEach-Object {$_.text} | Where-Object {$_}) -join ' / '
 }
 return @{id=$shape.Id;name=$shape.Name;type=$shape.Type;topLevel=$topLevel;left=$shape.Left;top=$shape.Top;width=$shape.Width;height=$shape.Height;zOrder=$shape.ZOrderPosition;text=$summary;children=$children}
}
function Test-IntegerId($value) {
 return ($value -is [int] -or $value -is [long]) -and $value -gt 0 -and $value -le [int]::MaxValue
}
$source=(Resolve-Path -LiteralPath $SourcePath).ProviderPath
$sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
$report=[IO.Path]::GetFullPath($ReportPath)
if(Test-Path -LiteralPath $report){throw 'ReportPath already exists; use a new audit filename.'}
if($Mode -eq 'apply') {
 if(-not $PlanPath -or -not $OutputPath){throw 'apply requires PlanPath and OutputPath.'}
 $output=[IO.Path]::GetFullPath($OutputPath)
 if([IO.Path]::GetExtension($output) -ne '.pptx'){throw 'Output must be .pptx.'}
 if($output -eq $source -or $report -eq $output){throw 'Source, output and report must be distinct.'}
 if(Test-Path -LiteralPath $output){throw 'Output already exists; use a new candidate filename.'}
 $plan=Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
 if(-not $plan.inputSha256 -or $plan.inputSha256.ToLowerInvariant() -ne $sourceHash){throw 'Plan source SHA256 mismatch; inspect the actual source again.'}
 if($null -eq $plan.slides -or -not @($plan.slides).Count){throw 'Plan has no slides.'}
}
$app=$null
$deck=$null
try {
 $app=New-Object -ComObject PowerPoint.Application
 # Read-only opening; edits are saved only to a new candidate.
 $deck=$app.Presentations.Open($source,-1,0,0)
 $inventory=@()
 for($si=1;$si -le $deck.Slides.Count;$si++) {
  $slide=$deck.Slides.Item($si)
  $shapes=@()
  foreach($shape in $slide.Shapes) {
   $shapes+=Get-ShapeRecord $shape $true
  }
  $effects=@()
  foreach($effect in $slide.TimeLine.MainSequence) {
   $direction=$null
   try{$direction=$effect.EffectParameters.Direction}catch{}
   $effects+=@{shapeId=$effect.Shape.Id;effect=$effect.EffectType;direction=$direction;trigger=$effect.Timing.TriggerType;duration=$effect.Timing.Duration;delay=$effect.Timing.TriggerDelayTime}
  }
  $inventory+=@{slide=$si;hidden=($slide.SlideShowTransition.Hidden -eq -1);shapes=$shapes;effects=$effects}
 }
 $result=@{sourcePath=$source;inputSha256=$sourceHash;slideCount=$deck.Slides.Count;slideWidth=$deck.PageSetup.SlideWidth;slideHeight=$deck.PageSetup.SlideHeight;slides=$inventory}
 if($Mode -eq 'apply') {
  $effectIds=@{fade=10;wipe=22;fadedZoom=48}
  $directions=@{fromLeft=4;fromRight=2;fromTop=3;fromBottom=1}
  $seenSlides=@{}
  # Validate the entire plan before altering any slide.
  foreach($entry in $plan.slides) {
   if(-not(Test-IntegerId $entry.slide)){throw 'Invalid slide ID: expected a positive integer.'}
   $si=[int]$entry.slide
   if($si -lt 1 -or $si -gt $deck.Slides.Count -or $seenSlides.ContainsKey($si)){throw "Invalid or duplicate slide: $si"}
   $seenSlides[$si]=$true
   $slide=$deck.Slides.Item($si)
   if($slide.TimeLine.MainSequence.Count -gt 0 -and -not $ReplaceExisting){throw "Slide $si already has effects. Use ReplaceExisting only for intentional replacement."}
   if($slide.TimeLine.InteractiveSequences.Count -gt 0){throw "Slide $si has interactive sequences; use a dedicated workflow."}
   if($null -eq $entry.groups -or -not @($entry.groups).Count){throw "Slide ${si}: no groups; refusing to clear existing animations."}
   $ids=@{}
   foreach($shape in $slide.Shapes){$ids[[int]$shape.Id]=$true}
   $used=@{}
   $end=0.0
   foreach($group in $entry.groups) {
    if(-not $group.label -or -not $effectIds.ContainsKey([string]$group.effect)){throw "Slide ${si}: invalid label or effect."}
    $start=[double]$group.start
    $duration=[double]$group.duration
    if([double]::IsNaN($start) -or [double]::IsInfinity($start) -or [double]::IsNaN($duration) -or [double]::IsInfinity($duration) -or $duration -le 0 -or $start -lt 0 -or $start -lt ($end-0.0001)){throw "Slide ${si}: invalid or overlapping timing."}
    if($null -eq $group.start -or $null -eq $group.duration){throw "Slide ${si}: start and duration required."}
    $end=$start+$duration
    if($group.direction -and ($group.effect -ne 'wipe' -or -not $directions.ContainsKey([string]$group.direction))){throw "Slide ${si}: unsupported direction."}
    if(-not @($group.shapeIds).Count){throw "Slide ${si}: empty component."}
    foreach($id in $group.shapeIds) {
     if(-not(Test-IntegerId $id)){throw "Slide ${si}: shape ID must be a positive integer."}
     $key=[int]$id
     if(-not $ids.ContainsKey($key) -or $used.ContainsKey($key)){throw "Slide ${si}: absent or reused top-level shape ID $key"}
     $used[$key]=$true
    }
   }
  }
  $audit=@()
  foreach($entry in $plan.slides) {
   $si=[int]$entry.slide
   $slide=$deck.Slides.Item($si)
   while($slide.TimeLine.MainSequence.Count -gt 0){$slide.TimeLine.MainSequence.Item(1).Delete()}
   $lookup=@{}
   foreach($shape in $slide.Shapes){$lookup[[int]$shape.Id]=$shape}
   $end=0.0
   $timings=@()
   foreach($group in $entry.groups) {
    $names=@()
    foreach($id in $group.shapeIds) {
     $selected=$lookup[[int]$id]
     $selected.Name="PPTAnim_${si}_$id"
     $names+=$selected.Name
    }
    if($names.Count -gt 1){
     try{$component=$slide.Shapes.Range([object[]]$names).Group()}
     catch{throw "Slide $si component '$($group.label)' cannot be grouped. Check source shape locks or pre-group in PowerPoint. $($_.Exception.Message)"}
    }else{$component=$lookup[[int]$group.shapeIds[0]]}
    $component.Name="Animation_$($group.label)"
    $effect=$slide.TimeLine.MainSequence.AddEffect($component,[int]$effectIds[[string]$group.effect],0,3)
    # Direction setters can reset effect timing. Configure them first.
    if($group.direction){$effect.EffectParameters.Direction=[int]$directions[[string]$group.direction]}
    $effect.Timing.Accelerate=0.15
    $effect.Timing.Decelerate=0.45
    $effect.Timing.Duration=[single]$group.duration
    # Use the double overload: Max(0, fractionalGap) can round the gap to an integer in PowerShell.
    $effect.Timing.TriggerDelayTime=[single]([math]::Max([double]0,([double]$group.start-$end)))
    if([math]::Abs($effect.Timing.Duration-[double]$group.duration) -gt 0.02){throw 'PowerPoint changed the planned duration.'}
    if([math]::Abs($effect.Timing.TriggerDelayTime-([double]$group.start-$end)) -gt 0.02){throw 'PowerPoint changed the planned delay.'}
    $end=[double]$group.start+[double]$group.duration
    $timings+=@{label=$group.label;start=[double]$group.start;duration=$effect.Timing.Duration;delay=$effect.Timing.TriggerDelayTime;trigger=$effect.Timing.TriggerType}
   }
   # Do not change source transition type/duration or hidden status.
   $slide.SlideShowTransition.AdvanceOnClick=-1
   $slide.SlideShowTransition.AdvanceOnTime=0
   $audit+=@{slide=$si;effects=$slide.TimeLine.MainSequence.Count;entrySeconds=$end;timings=$timings}
  }
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))
  $deck.SaveAs($output,24)
  $deck.Close()
  $deck=$null
  $deck=$app.Presentations.Open($output,-1,0,0)
  if($deck.Slides.Count -ne $inventory.Count){throw 'Saved slide count changed.'}
  foreach($original in $inventory){
   if(($deck.Slides.Item([int]$original.slide).SlideShowTransition.Hidden -eq -1) -ne $original.hidden){throw 'Saved hidden-page state changed.'}
  }
  foreach($entry in $plan.slides){
   $sequence=$deck.Slides.Item([int]$entry.slide).TimeLine.MainSequence
   if($sequence.Count -ne @($entry.groups).Count){throw 'Saved effect count differs from plan.'}
   $actualEnd=0.0
   for($i=1;$i -le $sequence.Count;$i++){
    $effect=$sequence.Item($i)
    $want=$entry.groups[$i-1]
    $actualStart=$actualEnd+$effect.Timing.TriggerDelayTime
    if($effect.Timing.TriggerType -ne 3 -or [math]::Abs($actualStart-[double]$want.start) -gt 0.025 -or [math]::Abs($effect.Timing.Duration-[double]$want.duration) -gt 0.025){throw 'Saved timing differs from plan.'}
    $actualEnd=$actualStart+$effect.Timing.Duration
   }
  }
  $result=@{sourcePath=$source;inputSha256=$sourceHash;outputPath=$output;outputSha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant();slideCount=$deck.Slides.Count;slides=$audit;savedTimingVerified=$true;validation='Candidate only: render comparison and real playback remain required.'}
 }
 [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
 $result | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $report -Encoding UTF8
 Write-Output "Saved $Mode report: $report"
} finally {
 if($null -ne $deck){$deck.Close()}
 # Never close other presentations or quit a user's active PowerPoint session.
 if($null -ne $app -and $app.Presentations.Count -eq 0){$app.Quit()}
 if($null -ne $deck){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($deck)}
 if($null -ne $app){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($app)}
}
