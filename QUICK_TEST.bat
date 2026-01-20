@echo off
cmd /k "cd /d %~dp0legal_ai_app && flutter pub get && flutter test && echo. && echo Tests complete! && pause"
