@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Monster Studio - installation de TripoSR
echo ============================================================
echo   Monster Studio : installation de l'IA 2D vers 3D (TripoSR)
echo ============================================================
echo.
echo Ce script installe TripoSR en local, dans un environnement isole.
echo Il faut : Python 3.11 ^(ou 3.10^), Git, une carte NVIDIA a jour.
echo Aucun compilateur n'est necessaire.
echo Duree : 10 a 30 minutes, environ 6 Go telecharges.
echo.

set "HERE=%~dp0"
rem --- dossier d'installation (argument 1 facultatif)
set "TRIPO=%~1"
if "%TRIPO%"=="" set "TRIPO=%USERPROFILE%\TripoSR"
echo Dossier d'installation : %TRIPO%
echo.

rem --- verifications
set "PY="
where py >nul 2>nul && py -3.11 -c "import sys" >nul 2>nul && set "PY=py -3.11"
if "%PY%"=="" where py >nul 2>nul && py -3.10 -c "import sys" >nul 2>nul && set "PY=py -3.10"
if "%PY%"=="" where python >nul 2>nul && set "PY=python"
if "%PY%"=="" (
  echo [ERREUR] Python est introuvable. Installez Python 3.11 ^(64 bits^) depuis python.org
  echo          en cochant "Add python.exe to PATH", puis relancez ce script.
  goto :fail
)
%PY% -c "import sys; sys.exit(0 if (3,10) <= sys.version_info[:2] <= (3,11) else 1)" >nul 2>nul
if errorlevel 1 (
  echo [ERREUR] TripoSR demande Python 3.10 ou 3.11 : les versions plus recentes ^(3.12 et plus^)
  echo          n'ont pas toutes les dependances prevues. Version trouvee :
  %PY% --version
  echo          Installez Python 3.11 ^(64 bits^) depuis python.org ^(il peut cohabiter avec l'autre^),
  echo          puis relancez ce script : il utilisera automatiquement la 3.11.
  goto :fail
)
where git >nul 2>nul
if errorlevel 1 (
  echo [ERREUR] Git est introuvable. Installez-le depuis git-scm.com puis relancez ce script.
  goto :fail
)
where nvidia-smi >nul 2>nul
if errorlevel 1 (
  echo [ATTENTION] Aucune carte NVIDIA detectee : l'IA fonctionnera sur le processeur, tres lentement.
  echo.
)
rem --- TripoSR
if exist "%TRIPO%\run.py" goto :have_repo
echo [1/5] Telechargement de TripoSR...
git clone https://github.com/VAST-AI-Research/TripoSR "%TRIPO%"
if errorlevel 1 goto :fail
goto :after_repo
:have_repo
echo [1/5] TripoSR est deja telecharge.
:after_repo
cd /d "%TRIPO%"
if errorlevel 1 goto :fail

rem --- environnement isole
if not exist "venv\Scripts\python.exe" goto :make_venv
"venv\Scripts\python.exe" -c "import sys; sys.exit(0 if (3,10) <= sys.version_info[:2] <= (3,11) else 1)" >nul 2>nul
if not errorlevel 1 goto :have_venv
echo [2/5] Ancien environnement cree avec une autre version de Python : on le refait.
rmdir /s /q venv
:make_venv
echo [2/5] Creation de l'environnement Python...
%PY% -m venv venv
if errorlevel 1 goto :fail
goto :after_venv
:have_venv
echo [2/5] Environnement Python deja cree.
:after_venv
set "VPY=%TRIPO%\venv\Scripts\python.exe"
"%VPY%" -m pip install --upgrade pip wheel
if errorlevel 1 goto :fail

rem --- PyTorch avec CUDA
echo [3/5] Installation de PyTorch ^(CUDA 12.1^), environ 3 Go...
"%VPY%" -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
if errorlevel 1 goto :fail

rem --- dependances de TripoSR (sans torchmcubes : il demande un compilateur ; un remplacant en Python pur est copie a la place)
echo [4/5] Installation des dependances de TripoSR...
if not exist "%HERE%triposr_shim\torchmcubes.py" (
  echo [ERREUR] Fichier manquant : triposr_shim\torchmcubes.py ^(a cote de ce script^). Recuperez le dossier monster-studio complet.
  goto :fail
)
findstr /v /i "torchmcubes" requirements.txt > requirements_sans_mcubes.txt
"%VPY%" -m pip install --prefer-binary -r requirements_sans_mcubes.txt scikit-image onnxruntime "numpy<2"
if errorlevel 1 goto :fail
copy /y "%HERE%triposr_shim\torchmcubes.py" "%TRIPO%\torchmcubes.py" >nul
if errorlevel 1 goto :fail

rem --- essai complet (telecharge aussi le modele, quelques centaines de Mo)
echo [5/5] Essai de TripoSR ^(premier lancement : telechargement du modele^)...
if exist "essai" rmdir /s /q "essai"
"%VPY%" run.py examples\chair.png --output-dir essai --model-save-format glb
if exist "essai\0\mesh.glb" goto :test_ok
echo [ERREUR] L'essai n'a pas produit de modele 3D ^(essai\0\mesh.glb^).
goto :fail
:test_ok
echo.
echo Essai reussi : essai\0\mesh.glb

rem --- reglages de Monster Studio
set "SET_DIR=%APPDATA%\Godot\app_userdata\Monster Studio\studio"
set "SET_FILE=%SET_DIR%\settings.json"
set "TRIPO_J=%TRIPO:\=/%"
if exist "%SET_FILE%" goto :settings_exist
if not exist "%SET_DIR%" mkdir "%SET_DIR%"
> "%SET_FILE%" echo {
>> "%SET_FILE%" echo 	"workdir": "%TRIPO_J%",
>> "%SET_FILE%" echo 	"command": "venv\\Scripts\\python.exe run.py \"{image}\" --output-dir \"{outdir}\" --model-save-format glb",
>> "%SET_FILE%" echo 	"result": "{outdir}/0/mesh.glb",
>> "%SET_FILE%" echo 	"export_dir": ""
>> "%SET_FILE%" echo }
echo Reglages de Monster Studio ecrits : %SET_FILE%
goto :settings_done
:settings_exist
echo.
echo Des reglages Monster Studio existent deja : ils ne sont pas modifies.
echo Dans Monster Studio, bouton Reglages, saisissez :
echo   Dossier   : %TRIPO%
echo   Commande  : venv\Scripts\python.exe run.py "{image}" --output-dir "{outdir}" --model-save-format glb
echo   Resultat  : {outdir}/0/mesh.glb
:settings_done
echo.
echo ============================================================
echo   Installation terminee. Lancez Monster Studio, onglet 1,
echo   source "IA locale", puis "Creer le modele 3D".
echo ============================================================
echo.
pause
exit /b 0

:fail
echo.
echo ============================================================
echo [ERREUR] L'installation s'est arretee. Lisez le message ci-dessus.
echo Vous pouvez relancer ce script : il reprend ou il s'est arrete.
echo ============================================================
echo.
pause
exit /b 1
