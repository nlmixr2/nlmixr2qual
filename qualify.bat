@echo off
REM Windows convenience wrapper for the nlmixr2 qualification run.
REM Exits with the runner's status (0 = PASS, 1 = FAIL) for pipeline gating.
Rscript run_qualification.R %*
exit /b %ERRORLEVEL%
