# run_simulation_awake.ps1 — run R/20_simulation.R while preventing idle sleep, restarting
# automatically if the run stops before all tasks are complete
#
# Windows suspends running processes during sleep and the PSOCK workers do not survive it
# (the first full run stopped at 22:42 on 13 Sep 2026 when the PC slept). This wrapper asks
# Windows to stay awake only while the simulation runs (SetThreadExecutionState, the same
# per-process mechanism media players use). It changes no power settings; the request ends
# when this script exits. Closing a laptop lid or choosing Sleep still sleeps the machine.
#
# If a worker process dies, the driver stops with "error reading connection" (seen at 12:49 on
# 14 Sep 2026). Because every replicate is saved on completion and reproducible from its own
# seed, the wrapper simply relaunches the driver, which skips completed tasks. It stops when
# all tasks are done, after MaxAttempts launches, or if a launch completes no new tasks
# (which would indicate a deterministic failure needing investigation).
#
# Usage (from the repo root):
#   powershell -ExecutionPolicy Bypass -File R\run_simulation_awake.ps1 full

param(
  [ValidateSet("pilot", "full")][string]$Mode = "full",
  [int]$MaxAttempts = 30
)

$root   = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "data\derived\sim_$Mode"
$runLog = Join-Path $outDir "driver_runs.log"
$target = if ($Mode -eq "full") { 6200 } else { 184 }
New-Item -ItemType Directory -Force $outDir | Out-Null

Add-Type -Namespace Win32 -Name Power -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
$ES_CONTINUOUS      = [uint32]"0x80000000"
$ES_SYSTEM_REQUIRED = [uint32]"0x00000001"

function Count-Done { (Get-ChildItem (Join-Path $outDir "s*_r*.rds") -ErrorAction SilentlyContinue).Count }
function Log([string]$msg) { Add-Content $runLog "$(Get-Date -Format s) $msg" }

try {
  [void][Win32.Power]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $before = Count-Done
    if ($before -ge $target) { Log "all $target tasks complete"; break }
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Log "start mode=$Mode attempt=$attempt done=$before (keep-awake on)"
    $p = Start-Process -FilePath "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" `
      -ArgumentList "R/20_simulation.R", $Mode -WorkingDirectory $root -NoNewWindow -PassThru -Wait `
      -RedirectStandardOutput (Join-Path $outDir "driver_stdout_$stamp.log") `
      -RedirectStandardError (Join-Path $outDir "driver_stderr_$stamp.log")
    $after = Count-Done
    Log "end attempt=$attempt exit=$($p.ExitCode) done=$after (+$($after - $before))"
    if ($after -ge $target) { Log "all $target tasks complete"; break }
    if ($after -le $before) { Log "no progress in attempt $attempt; stopping for investigation"; break }
    Start-Sleep -Seconds 10   # let orphaned workers exit and sockets close before relaunch
  }
} finally {
  [void][Win32.Power]::SetThreadExecutionState($ES_CONTINUOUS)
  Log "wrapper exit"
}
