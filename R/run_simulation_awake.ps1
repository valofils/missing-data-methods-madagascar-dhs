# run_simulation_awake.ps1 — run R/20_simulation.R while preventing idle sleep
#
# Windows suspends running processes during sleep and the PSOCK workers do not survive it
# (the first full run stopped at 22:42 on 13 Sep 2026 when the PC slept). This wrapper asks
# Windows to stay awake only while the simulation runs (SetThreadExecutionState, the same
# per-process mechanism media players use). It changes no power settings; the request ends
# when this script exits. Closing a laptop lid or choosing Sleep still sleeps the machine.
#
# Usage (from the repo root; resumes automatically, skipping completed replicates):
#   powershell -ExecutionPolicy Bypass -File R\run_simulation_awake.ps1 full

param([ValidateSet("pilot", "full")][string]$Mode = "full")

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "data\derived\sim_$Mode"
New-Item -ItemType Directory -Force $outDir | Out-Null

Add-Type -Namespace Win32 -Name Power -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
$ES_CONTINUOUS = [uint32]"0x80000000"
$ES_SYSTEM_REQUIRED = [uint32]"0x00000001"

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
try {
  [void][Win32.Power]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
  Add-Content (Join-Path $outDir "driver_runs.log") "$(Get-Date -Format s) start mode=$Mode (keep-awake on)"
  $p = Start-Process -FilePath "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" `
    -ArgumentList "R/20_simulation.R", $Mode -WorkingDirectory $root -NoNewWindow -PassThru -Wait `
    -RedirectStandardOutput (Join-Path $outDir "driver_stdout_$stamp.log") `
    -RedirectStandardError (Join-Path $outDir "driver_stderr_$stamp.log")
  Add-Content (Join-Path $outDir "driver_runs.log") "$(Get-Date -Format s) end exit=$($p.ExitCode)"
} finally {
  [void][Win32.Power]::SetThreadExecutionState($ES_CONTINUOUS)
}
