@echo off
rem launch_simulation.cmd — start the full RQ3 simulation (double-click, or run from a terminal)
rem
rem Runs R\run_simulation_awake.ps1 in a hidden window as an ordinary desktop process: keeps the
rem machine from idle-sleeping, resumes from saved replicates, and restarts automatically if the
rem run stops early. Progress: data\derived\sim_full\progress.log and driver_runs.log.
rem Keep the charger connected and the lid open; sleep, shutdown or a Windows restart still stop it.

cd /d "%~dp0.."
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0run_simulation_awake.ps1" full
echo Simulation launched. Progress: data\derived\sim_full\progress.log
