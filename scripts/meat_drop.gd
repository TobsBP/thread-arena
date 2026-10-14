class_name MeatDrop
extends RefCounted

## Carne largada por uma ovelha morta (ver main.gd _resolve_sheep_hits).
## Fica parada no chão até algum player chegar perto (cura — ver
## _resolve_meat_pickup) ou LIFETIME passar sem ninguém pegar.

const LIFETIME := 20.0
const TEXTURE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Resources/M_Idle.png")

var pos: Vector2
var age := 0.0


func _init(spawn_pos: Vector2) -> void:
	pos = spawn_pos


func step(delta: float) -> void:
	age += delta


func is_expired() -> bool:
	return age >= LIFETIME
