<#
  Seven robotic arm - interactive calibration jogger (COM7 @ 115200)

  Jog each joint with the arrow keys until the arm PHYSICALLY sits at its true
  rest pose, then press Enter. That pose is stored to EEPROM as the new
  90/90/90 reference (the firmware's -C command), so every later coordinate
  command is measured from it.

  Note: hobby servos have no position feedback, so the arm cannot be posed by
  hand and read back. You nudge, you look, you nudge again.
#>

$ErrorActionPreference = 'Stop'

$PORT = 'COM7'
$BAUD = 115200

# Limits come straight from the ServoConfig construction in main.ino
$LIM  = @{ base = @(0, 180); shoulder = @(0, 110); elbow = @(20, 180) }
$GRIP_LIM = @(0, 100)

# Joint angles as COMMANDED (target). On connect the board resets, so target is 90.
$ang      = [ordered]@{ base = 90.0; shoulder = 90.0; elbow = 90.0 }
$order    = @('base', 'shoulder', 'elbow')
$sel      = 0
$step     = 1.0
$steps    = @(0.5, 1.0, 2.0, 5.0)
$stepIdx  = 1
$grip     = 50.0

$sp = New-Object System.IO.Ports.SerialPort $PORT, $BAUD, 'None', 8, 'One'
$sp.NewLine = "`n"
$sp.DtrEnable = $true
$sp.Open()
Start-Sleep -Milliseconds 2200
$sp.ReadExisting() | Out-Null

function Send($cmd, $wait = 0) {
    $sp.WriteLine($cmd)
    if ($wait -gt 0) { Start-Sleep -Milliseconds $wait; return $sp.ReadExisting().Trim() }
    return ''
}

function PushArm() {
    Send ("M({0:0.##} {1:0.##} {2:0.##})" -f $ang.base, $ang.shoulder, $ang.elbow) | Out-Null
}

function Tip() {
    $sp.ReadExisting() | Out-Null
    return ((Send 'T' 400) -replace '.*position: ', '')
}

function Status($note = '') {
    $marks = $order | ForEach-Object {
        $m = if ($_ -eq $order[$sel]) { '>' } else { ' ' }
        "{0}{1}={2,-6:0.##}" -f $m, $_.Substring(0, 4), $ang[$_]
    }
    $line = ($marks -join ' ') + ("  grip={0,-5:0.##}  step={1}" -f $grip, $step)
    if ($note) { $line += "   $note" }
    Write-Host $line
}

Send 'S(30)' 400 | Out-Null      # slowest speed - calibration nudges are tiny
$grip = 50.0
Send 'G(50)' 800 | Out-Null      # gripper to mid-travel, off both hard limits
PushArm

Write-Host @"

=== SEVEN ARM CALIBRATION ($PORT) ===

GOAL: make the arm physically look like the digit "7" --
      upper arm straight UP, forearm straight FORWARD (horizontal), base centred.
      Then press Enter to make that pose the new 90/90/90.

  1 2 3        select joint   (1=base  2=shoulder  3=elbow)
  Up / Down    nudge selected joint by the step size
  Left / Right nudge the BASE (shortcut, no need to select it)
  [ / ]        step size:  0.5  1  2  5  degrees
  t            demo: move selected joint +10, pause, come back
               (use this if you cannot tell which way is which)
  a            type exact angles, e.g.  92 88 91
  p            print the computed tip position
  g            type a gripper angle (0-100) to find open/close values
  o / c        save current gripper angle as OPEN / CLOSE
  Enter        SAVE this pose to EEPROM as 90/90/90
  q or Esc     quit without saving joint offsets

"@
Status "tip $(Tip)"

function Nudge($jointName, $delta) {
    $new = $ang[$jointName] + $delta
    $lo, $hi = $LIM[$jointName]
    if ($new -lt $lo -or $new -gt $hi) {
        Status "LIMIT: $jointName allows $lo..$hi"
        return
    }
    $ang[$jointName] = $new
    PushArm
    Status
}

$running = $true
while ($running) {
    $k = [Console]::ReadKey($true)

    switch ($k.Key) {
        'UpArrow'    { Nudge $order[$sel]  $step; continue }
        'DownArrow'  { Nudge $order[$sel] (-$step); continue }
        'RightArrow' { Nudge 'base' (-$step); continue }   # base+ turns toward L, so Right = minus
        'LeftArrow'  { Nudge 'base'  $step; continue }

        'Escape' { $running = $false; continue }

        'Enter' {
            $ob = $ang.base - 90.0; $os = $ang.shoulder - 90.0; $oe = $ang.elbow - 90.0
            Write-Host ("  offsets to write: base={0:+0.##}  shoulder={1:+0.##}  elbow={2:+0.##}" -f $ob, $os, $oe)
            if ((Read-Host '  type YES to commit to EEPROM') -eq 'YES') {
                Write-Host ('  ' + (Send '-C' 1200))
                # -C resets the firmware target to 90/90/90 while the arm stays put,
                # so our counters must follow it back to 90.
                $ang.base = 90.0; $ang.shoulder = 90.0; $ang.elbow = 90.0
                Status 'saved - this pose IS 90/90/90 now'
            } else { Write-Host '  cancelled' }
            continue
        }
    }

    switch ($k.KeyChar) {
        '1' { $sel = 0; Status; continue }
        '2' { $sel = 1; Status; continue }
        '3' { $sel = 2; Status; continue }

        '[' { if ($stepIdx -gt 0) { $stepIdx-- }; $step = $steps[$stepIdx]; Status; continue }
        ']' { if ($stepIdx -lt $steps.Count - 1) { $stepIdx++ }; $step = $steps[$stepIdx]; Status; continue }

        'q' { $running = $false; continue }

        'p' { Status "tip $(Tip)"; continue }

        't' {
            $j = $order[$sel]
            $lo, $hi = $LIM[$j]
            $probe = if ($ang[$j] + 10 -le $hi) { 10 } elseif ($ang[$j] - 10 -ge $lo) { -10 } else { 0 }
            if ($probe -eq 0) { Status 'no room to demo'; continue }
            $home = $ang[$j]
            Write-Host "  demo: $j $(if ($probe -gt 0) {'+'})$probe deg - watch the arm"
            $ang[$j] = $home + $probe; PushArm; Start-Sleep -Milliseconds 2000
            $ang[$j] = $home;          PushArm; Start-Sleep -Milliseconds 2000
            Status 'back to where it was'
            continue
        }

        'a' {
            $raw = Read-Host '  enter base shoulder elbow (e.g. 92 88 91)'
            $parts = $raw -split '[\s,]+' | Where-Object { $_ }
            if ($parts.Count -ne 3) { Status 'need exactly 3 numbers'; continue }
            $ok = $true
            $cand = @{}
            for ($i = 0; $i -lt 3; $i++) {
                $v = 0.0
                if (-not [double]::TryParse($parts[$i], [ref]$v)) { $ok = $false; break }
                $lo, $hi = $LIM[$order[$i]]
                if ($v -lt $lo -or $v -gt $hi) {
                    Write-Host "  LIMIT: $($order[$i]) allows $lo..$hi (got $v)"; $ok = $false; break
                }
                $cand[$order[$i]] = $v
            }
            if (-not $ok) { Status 'unchanged'; continue }
            foreach ($j in $order) { $ang[$j] = $cand[$j] }
            PushArm; Start-Sleep -Milliseconds 1500
            Status "tip $(Tip)"
            continue
        }

        'g' {
            $raw = Read-Host "  gripper angle ($($GRIP_LIM[0])-$($GRIP_LIM[1]))"
            $v = 0.0
            if (-not [double]::TryParse($raw, [ref]$v)) { Status 'not a number'; continue }
            if ($v -lt $GRIP_LIM[0] -or $v -gt $GRIP_LIM[1]) { Status "LIMIT: gripper allows $($GRIP_LIM[0])..$($GRIP_LIM[1])"; continue }
            $grip = $v
            Send ("G({0:0.##})" -f $v) 1200 | Out-Null
            Status
            continue
        }

        'o' { Write-Host ('  ' + (Send ("-GO({0:0.##})" -f $grip) 900)); continue }
        'c' { Write-Host ('  ' + (Send ("-GC({0:0.##})" -f $grip) 900)); continue }
    }
}

$sp.Close()
Write-Host 'port closed'
