extends SceneTree
func _init() -> void:
	var aabb := AABB(Vector3(-0.8, 0, -0.4), Vector3(1.6, 2.0, 0.8))
	var bones := SkeletonTemplates.build("winged", aabb)
	var v := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 100000:
		v.append(aabb.position + Vector3(rng.randf(), rng.randf(), rng.randf()) * aabb.size)
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = await Skinning.compute(v, bones, null)
	print("100000 sommets, ", bones.size(), " os : ", Time.get_ticks_msec() - t0, " ms")
	quit()
