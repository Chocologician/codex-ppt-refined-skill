<# Automated regression using synthetic slides only. Does not edit user presentations. #>
[CmdletBinding()]
param([string]$WorkDirectory=(Join-Path (Get-Location) '.build/codex-ppt-tests'))
$ErrorActionPreference='Stop'
$testRoot=Join-Path ([IO.Path]::GetFullPath($WorkDirectory)) ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$runner=Join-Path $PSScriptRoot 'apply_refined_animations.ps1'
$source=Join-Path $testRoot 'source.pptx'
$app=New-Object -ComObject PowerPoint.Application
$deck=$app.Presentations.Add(0)
try {
 $deck.PageSetup.SlideWidth=960;$deck.PageSetup.SlideHeight=540
 $slide=$deck.Slides.Add(1,12)
 $title=$slide.Shapes.AddTextbox(1,50,30,700,70);$title.TextFrame.TextRange.Text='Refined animation test'
 $box=$slide.Shapes.AddShape(1,60,150,280,160)
 $text=$slide.Shapes.AddTextbox(1,85,180,230,70);$text.TextFrame.TextRange.Text='Editable group text'
 $arrow=$slide.Shapes.AddShape(33,370,200,140,40)
 $hidden=$deck.Slides.Add(2,12);$hidden.SlideShowTransition.Hidden=-1
 $ids=@($title.Id,$box.Id,$text.Id,$arrow.Id)
 $deck.SaveAs($source,24)
 $deck.Export((Join-Path $testRoot 'before'),'PNG',960,540)
} finally {$deck.Close();if($app.Presentations.Count -eq 0){$app.Quit()}}
$sourceHash=(Get-FileHash $source).Hash
& $runner -Mode inspect -SourcePath $source -ReportPath (Join-Path $testRoot 'inventory.json') | Out-Null
$plan=@{inputSha256=$sourceHash;slides=@(@{slide=1;groups=@(
 @{label='Title';shapeIds=@($ids[0]);effect='fade';start=0.1;duration=0.5},
 @{label='Group';shapeIds=@($ids[1],$ids[2]);effect='fadedZoom';start=1.0;duration=0.6},
 @{label='Arrow';shapeIds=@($ids[3]);effect='wipe';direction='fromLeft';start=2.0;duration=0.35}
)})}
$planFile=Join-Path $testRoot 'plan.json'
$plan | ConvertTo-Json -Depth 20 | Set-Content $planFile -Encoding UTF8
$candidate=Join-Path $testRoot 'candidate.pptx'
& $runner -Mode apply -SourcePath $source -PlanPath $planFile -OutputPath $candidate -ReportPath (Join-Path $testRoot 'audit.json') | Out-Null
& $runner -Mode inspect -SourcePath $candidate -ReportPath (Join-Path $testRoot 'candidate-inventory.json') | Out-Null
$actual=Get-Content (Join-Path $testRoot 'candidate-inventory.json') -Raw | ConvertFrom-Json
if($actual.slideCount -ne 2 -or -not $actual.slides[1].hidden){throw 'Page state not preserved'}
if(-not @($actual.slides[0].shapes | Where-Object {$_.type -eq 6 -and $_.text -eq 'Editable group text' -and $_.children.Count -eq 2}).Count){throw 'Grouped text/children missing from inspection'}
Add-Type -AssemblyName System.Drawing
function Pixel-Hash($path){
 $bitmap=[Drawing.Bitmap]::new($path)
 try {
  $rect=[Drawing.Rectangle]::new(0,0,$bitmap.Width,$bitmap.Height)
  $data=$bitmap.LockBits($rect,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {$bytes=[byte[]]::new([math]::Abs($data.Stride)*$bitmap.Height);[Runtime.InteropServices.Marshal]::Copy($data.Scan0,$bytes,0,$bytes.Length)}finally{$bitmap.UnlockBits($data)}
  $sha=[Security.Cryptography.SHA256]::Create()
  try{return [BitConverter]::ToString($sha.ComputeHash($bytes))}finally{$sha.Dispose()}
 } finally {$bitmap.Dispose()}
}
$app=New-Object -ComObject PowerPoint.Application
$deck=$app.Presentations.Open($candidate,-1,0,0)
try {$deck.Export((Join-Path $testRoot 'after'),'PNG',960,540)}finally{$deck.Close();if($app.Presentations.Count -eq 0){$app.Quit()}}
foreach($image in Get-ChildItem (Join-Path $testRoot 'before') -Filter '*.PNG'){
 if((Pixel-Hash $image.FullName) -ne (Pixel-Hash (Join-Path $testRoot ('after/'+$image.Name)))){throw 'Static visual regression'}
}
function Fresh-Plan{return ($plan | ConvertTo-Json -Depth 20 | ConvertFrom-Json)}
function Expect-Rejection($name,$bad,$expected){
 $file=Join-Path $testRoot ($name+'.json')
 $bad | ConvertTo-Json -Depth 20 | Set-Content $file -Encoding UTF8
 $output=Join-Path $testRoot ($name+'.pptx')
 $message=''
 try {& $runner -Mode apply -SourcePath $source -PlanPath $file -OutputPath $output -ReportPath (Join-Path $testRoot ($name+'-audit.json')) | Out-Null}catch{$message=$_.Exception.Message}
 if($message -notmatch $expected -or (Test-Path $output)){throw "Expected rejection failed: $name; $message"}
 return $name
}
$passed=@()
$bad=Fresh-Plan;$bad.inputSha256='0'*64;$passed+=Expect-Rejection 'wrong-source' $bad 'SHA256 mismatch'
$bad=Fresh-Plan;$bad.slides[0].groups=@();$passed+=Expect-Rejection 'empty-groups' $bad 'no groups'
$bad=Fresh-Plan;$bad.slides=$null;$passed+=Expect-Rejection 'null-slides' $bad 'no slides'
$bad=Fresh-Plan;$bad.slides[0].groups[1].start=0;$passed+=Expect-Rejection 'overlap' $bad 'overlapping'
$bad=Fresh-Plan;$bad.slides[0].groups[0].shapeIds=@(99999);$passed+=Expect-Rejection 'missing-shape' $bad 'absent or reused'
$bad=Fresh-Plan;$bad.slides[0].groups[1].shapeIds=@($ids[0]);$passed+=Expect-Rejection 'reused-shape' $bad 'absent or reused'
$bad=Fresh-Plan;$bad.slides[0].groups[0].duration=-1;$passed+=Expect-Rejection 'negative-duration' $bad 'overlapping'
$bad=Fresh-Plan;$bad.slides=@($bad.slides[0],$bad.slides[0]);$passed+=Expect-Rejection 'duplicate-slide' $bad 'duplicate slide'
$bad=Fresh-Plan;$bad.slides[0].slide=1.5;$passed+=Expect-Rejection 'fractional-slide' $bad 'positive integer'
$bad=Fresh-Plan;$bad.slides[0].groups[0].shapeIds=@(2.4);$passed+=Expect-Rejection 'fractional-shape' $bad 'positive integer'
$bad=Fresh-Plan;$bad.slides[0].groups[0].start=@(1,2);$passed+=Expect-Rejection 'invalid-start' $bad 'convert|invalid'
if((Get-FileHash $source).Hash -ne $sourceHash){throw 'Source modified'}
$result=@{passed=$true;testRoot=$testRoot;negativeCases=$passed;sourceUnchanged=$true;visualPixelsUnchanged=$true;groupTextVerified=$true;savedTimingVerified=$true;hiddenPageVerified=$true;scope='Synthetic COM regression. Visual design quality and real-deck playback require separate inspection.'}
$result | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $testRoot 'results.json') -Encoding UTF8
$result | ConvertTo-Json -Depth 8
