extends RefCounted
## Tiny original procedural tones; no external audio dependency.
static func play(parent: Node, frequency: float = 660.0, duration: float = 0.11) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / sample_rate
		var envelope: float = sin(PI * float(i) / maxf(count, 1))
		var sample := int(sin(TAU * frequency * t) * envelope * 9000)
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -14
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
