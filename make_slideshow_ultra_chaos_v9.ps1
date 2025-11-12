<# 
ULTRA CHAOS slideshow v9 — by ChatGPT
- Maksymalnie „pokraczne” przejścia, grube logi, resume, fallbacki i ETA.
- Wymaga: ffmpeg.exe, ffprobe.exe w tym samym folderze co skrypt.
#>

param(
  [double]$OverlapRatio = 0.90,
  [int]$FPS = 30,
  [int]$WIDTH = 1920,
  [int]$HEIGHT = 1080,
  [int]$CRF = 20,
  [int]$ChunkSize = 60,
  [int]$StartChunk = 0,
  [int]$EndChunk = -1,
  [double]$MaxXfade = 55.0,       # xfade limit ~60 s => clamp 55 s
  [string]$Preset = "veryfast",   # veryfast/ultrafast/medium...
  [switch]$Recurse,
  [switch]$Resume,                # jeśli jest _tmp\music_full.wav -> pomijamy audio
  [switch]$VerboseMode
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Globalization
$culture = [System.Globalization.CultureInfo]::InvariantCulture

function Ensure-LiteralDir([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here
$ffmpeg  = Join-Path $here "ffmpeg.exe"
$ffprobe = Join-Path $here "ffprobe.exe"
if (-not (Test-Path -LiteralPath $ffmpeg))  { throw "ffmpeg.exe not found in '$here'." }
if (-not (Test-Path -LiteralPath $ffprobe)) { throw "ffprobe.exe not found in '$here'." }

$tmp     = Join-Path $here "_tmp_ultra_v9"
$segtmp  = Join-Path $tmp  "segments"
Ensure-LiteralDir $tmp
Ensure-LiteralDir $segtmp

$LogPath = Join-Path $tmp "make.log"
"==== ULTRA CHAOS v9 ====" | Out-File -LiteralPath $LogPath -Encoding UTF8

function Log([string]$msg) {
  $ts = (Get-Date).ToString("HH:mm:ss")
  $line = "[$ts] $msg"
  Write-Host $line
  $line | Out-File -LiteralPath $LogPath -Append -Encoding UTF8
}

function ProbeDurationSec([string]$path) {
  $o = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $path 2>$null
  $s = ($o -join "`n").Trim()
  $d = 0.0
  if (-not [double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $culture, [ref]$d)) { return 0.0 }
  return $d
}

Log "=== Start ==="
Log "Working dir: $here"
Log "Log file   : $LogPath"

# ======= ZBIERANIE PLIKÓW =======
$search = @{ LiteralPath = $here; File = $true }
if ($Recurse) { $search.Recurse = $true }

$imgs = Get-ChildItem @search | Where-Object { $_.Extension -match '^(?i)\.(jpg|jpeg|png)$' } | Sort-Object FullName
$audios = Get-ChildItem @search | Where-Object { $_.Extension -match '^(?i)\.(mp3|wav|m4a|aac|flac|ogg)$' } | Sort-Object FullName
Log ("Images: {0}" -f $imgs.Count)
Log ("Audio : {0}" -f $audios.Count)

if ($imgs.Count -eq 0) { throw "No images found." }
$music = Join-Path $tmp "music_full.wav"
$haveMusic = Test-Path -LiteralPath $music
if (($audios.Count -eq 0) -and -not $haveMusic) { throw "No audio found and music_full.wav not present." }

# ======= AUDIO =======
if ($Resume -and $haveMusic) {
  Log "[resume] Using existing music_full.wav"
} else {
  $audtmp  = Join-Path $tmp  "audionorm"
  Ensure-LiteralDir $audtmp
  $alist = Join-Path $audtmp "list.txt"
  if (Test-Path -LiteralPath $alist) { Remove-Item -LiteralPath $alist -Force }
  $idx = 0
  foreach ($a in $audios) {
    $idx++
    $wav = Join-Path $audtmp ("a_{0:D4}.wav" -f $idx)
    Log ("[audio] norm -> {0}" -f (Split-Path $wav -Leaf))
    & $ffmpeg  -y -loglevel error -hide_banner -stats -i $a.FullName -vn -ar 48000 -ac 2 -sample_fmt s16 -f wav $wav
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed while normalizing '$($a.Name)'" }
    ("file '{0}'" -f $wav) | Out-File -LiteralPath $alist -Append -Encoding UTF8
    $d = ProbeDurationSec $wav
    Log ("   -> {0} => {1:N2}s" -f $a.Name, $d)
  }
  Log "[audio] concat -> music_full.wav"
  & $ffmpeg -y -loglevel error -hide_banner -stats -f concat -safe 0 -i $alist -c copy $music
  if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed while concatenating audio." }
}

$totalAudio = ProbeDurationSec $music
Log ("Audio total : {0:N2} s" -f $totalAudio)

# ======= CZAS (dopasowanie do audio) =======
$N = [double]$imgs.Count
$r = [Math]::Min([Math]::Max($OverlapRatio, 0.0), 0.95)
$L0  = $totalAudio / ($N - $r*($N-1.0))
$T0  = $L0 * $r
$Tused = [Math]::Min($T0, $MaxXfade)
$L     = ($totalAudio + ($N-1.0)*$Tused) / $N
if ($L -le $Tused + 0.05) { $L = $Tused + 0.06 }
$step  = $L - $Tused

$Lstr = $L.ToString($culture)
$Tstr = $Tused.ToString($culture)
$Sstr = $step.ToString($culture)

$estTotal = $N*$L - ($N-1)*$Tused
Log ("Timing: L={0}  T={1}  step={2}  -> est total ~ {3:N2} s" -f $Lstr,$Tstr,$Sstr,$estTotal)

# ======= SEGMENTACJA =======
$totalChunks = [int][Math]::Ceiling($imgs.Count / [double]$ChunkSize)
if ($EndChunk -lt 0 -or $EndChunk -ge $totalChunks) { $EndChunk = $totalChunks - 1 }
if ($StartChunk -lt 0) { $StartChunk = 0 }
if ($StartChunk -gt $EndChunk) { throw "StartChunk > EndChunk (range invalid)." }
Log ("Chunks total : {0} (size={1})" -f $totalChunks,$ChunkSize)
Log ("Chunks to run: {0}..{1}" -f $StartChunk,$EndChunk)

# ======= ZESTAWY EFEKTÓW / PRZEJŚĆ =======
$trans_ULTRA = @(
  'fade','fadeblack','fadewhite','dissolve',
  'wipeleft','wiperight','wipeup','wipedown',
  'slideleft','slideright','slideup','slidedown',
  'circlecrop','rectcrop','pixelize','distance','radial',
  'circleopen','circleclose','vertopen','vertclose','horzopen','horzclose',
  'smoothleft','smoothright','smoothup','smoothdown'
)
$trans_SAFE = @('fade','dissolve','wipeleft','wiperight','wipeup','wipedown','slideleft','slideright','slideup','slidedown')
$fxs = @(
  '',
  'hflip','vflip','vflip,hflip',
  'eq=contrast=1.8:brightness=0.08:saturation=2.0',
  'eq=contrast=0.6:saturation=0.3:gamma=0.9',
  'hue=h=2*PI*t:s=3','hue=s=0',
  'boxblur=2:1','noise=alls=25:allf=t',
  'rotate=0.08*sin(n/5)','rotate=0.12*cos(n/9),boxblur=2',
  'hue=h=PI/2:s=3,eq=contrast=1.4',
  'negate','eq=contrast=2.2:brightness=0.12',
  'edgedetect=mode=colormix:high=0.2:low=0.05',
  'lutrgb=r=negval:g=negval:b=negval',
  'tblend=all_mode=difference,eq=contrast=2.0',
  'geq=r=255-g:b=255-r:g=255-b'
)

function Build-Graph([string]$graphPath, [int]$count, [string]$Lstr, [string]$Tstr, [string]$Sstr, $transitions, $fxs, [string]$metaPath) {
  $sb = New-Object System.Text.StringBuilder
  $mb = New-Object System.Text.StringBuilder
  $mb.AppendLine("CLIPS: $count  L=$Lstr  T=$Tstr  step=$Sstr") | Out-Null
  for ($i=0; $i -lt $count; $i++) {
    $fx = $fxs | Get-Random
    $scalePad = ("scale={0}:{1}:force_original_aspect_ratio=decrease,pad={0}:{1}:(ow-iw)/2:(oh-ih)/2" -f $WIDTH,$HEIGHT)
    $line = "[{0}:v]fps={1},{2},format=yuv420p" -f $i,$FPS,$scalePad
    if ($fx -ne '') { $line = "$line,$fx" }
    $line = "$line,trim=duration=$Lstr,setpts=PTS-STARTPTS[v$i];"
    $sb.AppendLine($line) | Out-Null
    $mb.AppendLine(("clip {0}: fx='{1}'" -f $i,$fx)) | Out-Null
  }
  if ($count -ge 2) {
    $prev = "v0"
    for ($k=1; $k -lt $count; $k++) {
      $t = $transitions | Get-Random
      $off = ([Math]::Round($k * [double]$Sstr,6)).ToString($culture)
      $outlbl = "vx$k"
      $sb.AppendLine("[${prev}][v${k}]xfade=transition=${t}:duration=${Tstr}:offset=${off}[${outlbl}];") | Out-Null
      $mb.AppendLine(("xfade {0}: {1}  dur={2}  off={3}" -f $k,$t,$Tstr,$off)) | Out-Null
      $prev = $outlbl
    }
  }
  [IO.File]::WriteAllText($graphPath, $sb.ToString())
  [IO.File]::WriteAllText($metaPath,  $mb.ToString())
}

function Run-FF([string[]]$args) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $ffmpeg
  $psi.Arguments = ($args -join " ")
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  while (-not $p.HasExited) {
    $line = $p.StandardError.ReadLine()
    if ($null -ne $line -and $line.Trim().Length -gt 0) {
      Write-Host $line
      $line | Out-File -LiteralPath $LogPath -Append -Encoding UTF8
    } else {
      Start-Sleep -Milliseconds 50
    }
  }
  while (-not $p.StandardError.EndOfStream) {
    $line = $p.StandardError.ReadLine()
    if ($line) { $line | Out-File -LiteralPath $LogPath -Append -Encoding UTF8; Write-Host $line }
  }
  return $p.ExitCode
}

# ======= RENDER SEGMENTÓW (ETA + fallbacki) =======
$segTimes = New-Object System.Collections.Generic.List[double]
$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

for ($seg=$StartChunk; $seg -le $EndChunk; $seg++) {
  $start = $seg * $ChunkSize
  $end   = [Math]::Min($start + $ChunkSize, $imgs.Count)
  $count = $end - $start
  if ($count -le 0) { continue }

  $segPath = Join-Path $segtmp ("seg_{0:D3}.mp4" -f $seg)
  $durExist = if (Test-Path -LiteralPath $segPath) { ProbeDurationSec $segPath } else { 0.0 }
  if ($durExist -gt 0.0) {
    Log ("[segment {0}] exists -> skip (dur={1:N1}s)" -f $seg,$durExist)
    continue
  }

  Log ("[segment {0}] build images {1}..{2} (count {3}) -> {4}" -f $seg, $start, ($end-1), $count, (Split-Path $segPath -Leaf))
  $graph   = Join-Path $tmp ("graph_seg_{0:D3}.txt" -f $seg)
  $metaTxt = Join-Path $tmp ("graph_seg_{0:D3}_meta.txt" -f $seg)

  # 1) ULTRA plan
  Build-Graph -graphPath $graph -count $count -Lstr $Lstr -Tstr $Tstr -Sstr $Sstr -transitions $trans_ULTRA -fxs $fxs -metaPath $metaTxt
  Log ("[segment {0}] effects & transitions (ULTRA):" -f $seg)
  Get-Content -LiteralPath $metaTxt | ForEach-Object { Log "  $_" }

  $args = New-Object 'System.Collections.Generic.List[string]'
  $args.Add("-y"); $args.Add("-loglevel"); $args.Add("error"); $args.Add("-hide_banner"); $args.Add("-stats")
  for ($i=$start; $i -lt $end; $i++) {
    $args.Add("-loop"); $args.Add("1"); $args.Add("-t"); $args.Add($Lstr); $args.Add("-i"); $args.Add($imgs[$i].FullName)
  }
  $finalLabel = if ($count -eq 1) { "v0" } else { "vx{0}" -f ($count-1) }
  $args.Add("-filter_complex_script"); $args.Add($graph)
  $args.Add("-map"); $args.Add("[${finalLabel}]")
  $args.Add("-an")
  $args.Add("-c:v"); $args.Add("libx264")
  $args.Add("-preset"); $args.Add($Preset)
  $args.Add("-crf"); $args.Add($CRF.ToString())
  $args.Add("-movflags"); $args.Add("+faststart")
  $args.Add($segPath)

  $swSeg = [System.Diagnostics.Stopwatch]::StartNew()
  $code = Run-FF ($args.ToArray())
  if ($code -ne 0) {
    Log ("[segment {0}] ULTRA failed (exit={1}) -> fallback A (T=10s, fade/dissolve)" -f $seg,$code)
    $T10 = "10.0"
    $S10 = ([Math]::Max($L - 10.0, 0.1)).ToString($culture)
    Build-Graph -graphPath $graph -count $count -Lstr $Lstr -Tstr $T10 -Sstr $S10 -transitions $trans_SAFE[0..1] -fxs $fxs -metaPath $metaTxt
    $args[$args.IndexOf("-filter_complex_script")+1] = $graph
    $code = Run-FF ($args.ToArray())
    if ($code -ne 0) {
      Log ("[segment {0}] fallback A failed -> fallback B (T=1s, fade)" -f $seg)
      $T1 = "1.0"
      $S1 = ([Math]::Max($L - 1.0, 0.1)).ToString($culture)
      Build-Graph -graphPath $graph -count $count -Lstr $Lstr -Tstr $T1 -Sstr $S1 -transitions @('fade') -fxs $fxs -metaPath $metaTxt
      $args[$args.IndexOf("-filter_complex_script")+1] = $graph
      $code = Run-FF ($args.ToArray())
      if ($code -ne 0) { throw "FFmpeg failed to build segment $seg even after fallbacks (exit=$code)." }
    }
  }
  $swSeg.Stop()
  $segTimes.Add($swSeg.Elapsed.TotalSeconds) | Out-Null
  $avg = ($segTimes | Measure-Object -Average).Average
  $done = ($seg - $StartChunk + 1)
  $remainSeg = ($EndChunk - $seg)
  $etaSec = [math]::Round($avg * $remainSeg)
  $etaEnd = (Get-Date).AddSeconds($etaSec).ToString("HH:mm:ss")
  Log ("[segment {0}] done in {1:c} | avg/seg ~ {2:N1}s | left {3} segs -> ETA ~ {4} (in {5})" -f $seg,$swSeg.Elapsed,$avg,$remainSeg,$etaEnd,([TimeSpan]::FromSeconds($etaSec).ToString()))
}

# ======= JOIN =======
$segFiles = Get-ChildItem -LiteralPath $segtmp -Filter "seg_*.mp4" | Sort-Object Name
if ($segFiles.Count -eq 0) {
  Log "[warn] No segments present to join. Exiting after segment stage."
  exit 0
}
Log ("Joining {0} segments..." -f $segFiles.Count)

$graphJoin = Join-Path $tmp "graph_join.txt"
$sbj = New-Object System.Text.StringBuilder
for ($i=0; $i -lt $segFiles.Count; $i++) {
  $sbj.AppendLine(("[{0}:v]setpts=PTS-STARTPTS[s{0}];" -f $i)) | Out-Null
}
$cum = ProbeDurationSec $segFiles[0].FullName
$prev = "s0"
for ($k=1; $k -lt $segFiles.Count; $k++) {
  $d = ProbeDurationSec $segFiles[$k].FullName
  $off = $cum - $Tused
  if ($off -lt 0) { $off = 0 }
  $offStr = ([Math]::Round($off,6)).ToString($culture)
  $lblOut = "sj$k"
  $t = $trans_SAFE | Get-Random
  $sbj.AppendLine("[${prev}][s${k}]xfade=transition=${t}:duration=${Tstr}:offset=${offStr}[${lblOut}];") | Out-Null
  $cum += $d - $Tused
  $prev = $lblOut
}
[IO.File]::WriteAllText($graphJoin, $sbj.ToString())

$argsJ = New-Object 'System.Collections.Generic.List[string]'
$argsJ.Add("-y"); $argsJ.Add("-loglevel"); $argsJ.Add("error"); $argsJ.Add("-hide_banner"); $argsJ.Add("-stats")
for ($i=0; $i -lt $segFiles.Count; $i++) { $argsJ.Add("-i"); $argsJ.Add($segFiles[$i].FullName) }
$videoJoined = Join-Path $tmp "video_joined.mp4"
$lastLbl = if ($segFiles.Count -eq 1) { "s0" } else { "sj{0}" -f ($segFiles.Count-1) }
$argsJ.Add("-filter_complex_script"); $argsJ.Add($graphJoin)
$argsJ.Add("-map"); $argsJ.Add("[${lastLbl}]")
$argsJ.Add("-an")
$argsJ.Add("-c:v"); $argsJ.Add("libx264")
$argsJ.Add("-preset"); $argsJ.Add($Preset)
$argsJ.Add("-crf"); $argsJ.Add($CRF.ToString())
$argsJ.Add("-movflags"); $argsJ.Add("+faststart")
$argsJ.Add($videoJoined)

$codeJ = Run-FF ($argsJ.ToArray())
if ($codeJ -ne 0) {
  Log "[join] xfade join failed -> fallback to concat demuxer (bez przejść między segmentami)"
  $listJoin = Join-Path $tmp "segments_list.txt"
  if (Test-Path -LiteralPath $listJoin) { Remove-Item -LiteralPath $listJoin -Force }
  foreach ($s in $segFiles) { ("file '{0}'" -f $s.FullName) | Out-File -LiteralPath $listJoin -Append -Encoding UTF8 }
  & $ffmpeg -y -loglevel error -hide_banner -stats -f concat -safe 0 -i $listJoin -c copy $videoJoined
  if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed while concat joining segments." }
}

# ======= MUX AUDIO =======
$outPath = Join-Path $here "slideshow_ultra_chaos_v9.mp4"
Log ("Mux audio -> {0}" -f (Split-Path $outPath -Leaf))
& $ffmpeg -y -loglevel error -hide_banner -stats -i $videoJoined -i $music -c:v copy -c:a aac -b:a 192k -movflags +faststart -shortest $outPath
if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed while muxing audio." }

$swTotal.Stop()
$finalDur = ProbeDurationSec $outPath
Log ("✅ FINISHED | video ~ {0:N2}s | total render time {1:c}" -f $finalDur,$swTotal.Elapsed)
Log ("Output: $outPath")
Log ("Log   : $LogPath")
Write-Host ""
Write-Host "✅ Done! Created: $outPath"
Write-Host "Log: $LogPath"
