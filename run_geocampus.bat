@echo off
echo Starting GeoCampus backends...

echo Starting web map assets on port 8080...
start cmd /k "cd web_assets && python -m http.server 8080 --bind 0.0.0.0"

if "%PLANTNET_API_KEY%"=="" (
  echo [!] PLANTNET_API_KEY is not set. Get a free key at https://my.plantnet.org
  set /p PLANTNET_API_KEY=Paste your PlantNet API key: 
)

echo Starting AI plant scanner (PlantNet) on port 8888...
start cmd /k "cd backend\plant_recognition && python plant_game_server.py"

echo Backends are running!
echo Make sure your phone is on the same Wi-Fi network as this PC.
echo Run "ipconfig" to find this PC's IP, then build the app with:
echo.
echo    cd frontend
echo    flutter run --dart-define=GEOCAMPUS_API=http://YOUR_PC_IP:8000/api/v1
echo.
pause
