@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Monster Studio - desinstallation de TripoSR
echo ============================================================
echo   Monster Studio : desinstallation de l'IA 2D vers 3D (TripoSR)
echo ============================================================
echo.
echo Ce script retire ce que install_triposr.bat a installe :
echo   - le dossier TripoSR ^(avec son environnement Python et PyTorch^)
echo   - les modeles d'IA telecharges ^(cache Hugging Face, modeles de detourage^)
echo   - si vous le souhaitez : le cache de pip et les reglages de Monster Studio
echo Il NE touche PAS a Python, a Git ni au logiciel Monster Studio lui-meme.
echo Vos monstres, modeles 3D et fichiers .glb exportes sont conserves,
echo sauf si vous repondez oui a la derniere question.
echo.

set "TRIPO=%~1"
if "%TRIPO%"=="" set "TRIPO=%USERPROFILE%\TripoSR"
echo Dossier de TripoSR : %TRIPO%
echo.

choice /c ON /n /m "Continuer la desinstallation ? [O]ui / [N]on : "
if errorlevel 2 goto :cancel

rem --- 1. dossier TripoSR (par prudence : seulement s'il ressemble bien a TripoSR)
if not exist "%TRIPO%" goto :no_tripo
if not exist "%TRIPO%\run.py" goto :not_tripo
if not exist "%TRIPO%\tsr" goto :not_tripo
echo.
echo [1/4] Suppression de %TRIPO% ...
rmdir /s /q "%TRIPO%"
if exist "%TRIPO%" echo [ATTENTION] Suppression incomplete : fermez les fenetres qui utilisent ce dossier puis relancez ce script.
if not exist "%TRIPO%" echo        Dossier supprime.
goto :models
:no_tripo
echo.
echo [1/4] Le dossier TripoSR n'existe pas : rien a supprimer.
goto :models
:not_tripo
echo.
echo [1/4] Ce dossier ne ressemble pas a TripoSR ^(run.py ou tsr absent^) : il n'est pas touche.
echo        Si TripoSR est ailleurs, relancez : uninstall_triposr.bat "C:\chemin\vers\TripoSR"

:models
rem --- 2. modeles d'IA telecharges
echo.
echo [2/4] Suppression des modeles d'IA telecharges...
set "HF=%USERPROFILE%\.cache\huggingface\hub"
if exist "%HF%\models--stabilityai--TripoSR" rmdir /s /q "%HF%\models--stabilityai--TripoSR"
if exist "%HF%\models--facebook--dino-vitb16" rmdir /s /q "%HF%\models--facebook--dino-vitb16"
if exist "%USERPROFILE%\.u2net" rmdir /s /q "%USERPROFILE%\.u2net"
echo        Fait.

rem --- 3. cache de pip (contient les gros fichiers PyTorch telecharges)
echo.
echo [3/4] Le cache de pip peut contenir plusieurs Go de fichiers PyTorch.
echo        ^(Il est partage avec vos autres programmes Python : ils les retelechargeront si besoin.^)
choice /c ON /n /m "Vider le cache de pip ? [O]ui / [N]on : "
if errorlevel 2 goto :settings
if exist "%LOCALAPPDATA%\pip\cache" rmdir /s /q "%LOCALAPPDATA%\pip\cache"
echo        Fait.

:settings
rem --- 4. reglages de Monster Studio
set "MS=%APPDATA%\Godot\app_userdata\Monster Studio\studio"
echo.
echo [4/4] Reglages de Monster Studio ^(dossier de l'IA, commande, dossier d'export^).
choice /c ON /n /m "Remettre a zero ces reglages ? [O]ui / [N]on : "
if errorlevel 2 goto :library
if exist "%MS%\settings.json" del /q "%MS%\settings.json"
echo        Fait.

:library
echo.
echo ------------------------------------------------------------
echo Derniere question, definitive :
echo Supprimer AUSSI toute la bibliotheque de Monster Studio ^(vos images importees,
echo modeles 3D, squelettes et animations en cours^) ? Les .glb deja exportes
echo dans d'autres dossiers ne sont pas concernes.
echo ------------------------------------------------------------
choice /c ON /n /m "Supprimer la bibliotheque ? [O]ui / [N]on (conseille : N) : "
if errorlevel 2 goto :done
if exist "%MS%" rmdir /s /q "%MS%"
echo        Bibliotheque supprimee.
goto :done

:cancel
echo.
echo Desinstallation annulee : rien n'a ete supprime.
echo.
pause
exit /b 0

:done
echo.
echo ============================================================
echo   Desinstallation terminee.
echo   Pour retirer aussi Python ou Git : Parametres Windows, puis
echo   Applications, Applications installees.
echo ============================================================
echo.
pause
exit /b 0
