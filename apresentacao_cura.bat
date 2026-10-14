@echo off
rem Abre 3 copias do jogo lado a lado, com os bots jogando, uma por modo de cura:
rem   cima-esquerda: menos vida   cima-direita: mais perto   baixo-esquerda: rodizio
rem Mesma semente nas tres: comecam iguais. Feche o editor do Godot antes (memoria).
rem Se o Godot estiver em outro lugar, troque o caminho abaixo.

set G="%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
cd /d "%~dp0"

start "" %G% --path . res://scenes/main.tscn --resolution 960x540 --position 0,0 -- --bots --threads --seed=7 --cura=0
start "" %G% --path . res://scenes/main.tscn --resolution 960x540 --position 960,0 -- --bots --threads --seed=7 --cura=1
start "" %G% --path . res://scenes/main.tscn --resolution 960x540 --position 0,540 -- --bots --threads --seed=7 --cura=2
