class_name AviWriter
extends RefCounted
## Écrit une vidéo AVI « Motion JPEG » (images JPEG à la suite) : lisible dans VLC et la plupart des lecteurs, sans aucun encodeur externe.
## Usage : var avi := AviWriter.new(largeur, hauteur, images_par_seconde) ; avi.add_jpeg(octets) pour chaque image ; avi.finish() → octets.

var width: int
var height: int
var fps: int
var _frames: Array[PackedByteArray] = []

func _init(w: int, h: int, f: int) -> void:
	width = w
	height = h
	fps = maxi(1, f)

func frame_count() -> int:
	return _frames.size()

func add_jpeg(data: PackedByteArray) -> void:
	_frames.append(data)

func finish() -> PackedByteArray:
	var max_frame := 0
	for f in _frames:
		max_frame = maxi(max_frame, f.size())
	# 1) liste « movi » : une portion '00dc' par image (alignée sur 2 octets), avec son index
	var movi := StreamPeerBuffer.new()
	movi.big_endian = false
	var idx := StreamPeerBuffer.new()
	idx.big_endian = false
	for f in _frames:
		var off := 4 + movi.get_size()           # 4 = le mot « movi » lui-même
		_cc(movi, "00dc")
		movi.put_u32(f.size())
		movi.put_data(f)
		if f.size() % 2 == 1:
			movi.put_u8(0)
		_cc(idx, "00dc")
		idx.put_u32(0x10)                          # AVIIF_KEYFRAME
		idx.put_u32(off)
		idx.put_u32(f.size())
	# 2) en-tête
	var strh := StreamPeerBuffer.new()
	strh.big_endian = false
	_cc(strh, "vids")
	_cc(strh, "MJPG")
	strh.put_u32(0)                                # flags
	strh.put_u16(0)                                # priorité
	strh.put_u16(0)                                # langue
	strh.put_u32(0)                                # images initiales
	strh.put_u32(1)                                # échelle
	strh.put_u32(fps)                              # cadence
	strh.put_u32(0)                                # début
	strh.put_u32(_frames.size())                   # longueur
	strh.put_u32(max_frame)
	strh.put_u32(0xFFFFFFFF)                       # qualité
	strh.put_u32(0)                                # taille d'échantillon
	strh.put_16(0)
	strh.put_16(0)
	strh.put_16(width)
	strh.put_16(height)
	var strf := StreamPeerBuffer.new()
	strf.big_endian = false
	strf.put_u32(40)
	strf.put_32(width)
	strf.put_32(height)
	strf.put_u16(1)
	strf.put_u16(24)
	_cc(strf, "MJPG")
	strf.put_u32(width * height * 3)
	strf.put_32(0)
	strf.put_32(0)
	strf.put_u32(0)
	strf.put_u32(0)
	var strl := _list("strl", _chunk("strh", strh.data_array) + _chunk("strf", strf.data_array))
	var avih := StreamPeerBuffer.new()
	avih.big_endian = false
	avih.put_u32(1000000 / fps)                    # µs par image
	avih.put_u32(max_frame * fps)                  # débit maximal
	avih.put_u32(0)
	avih.put_u32(0x10)                             # AVIF_HASINDEX
	avih.put_u32(_frames.size())
	avih.put_u32(0)
	avih.put_u32(1)                                # flux
	avih.put_u32(max_frame)
	avih.put_u32(width)
	avih.put_u32(height)
	for i in 4:
		avih.put_u32(0)
	var hdrl := _list("hdrl", _chunk("avih", avih.data_array) + strl)
	var body := PackedByteArray()
	body.append_array("AVI ".to_ascii_buffer())
	body.append_array(hdrl)
	body.append_array(_list("movi", movi.data_array))
	body.append_array(_chunk("idx1", idx.data_array))
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	out.append_array(_u32(body.size()))
	out.append_array(body)
	return out

static func _cc(b: StreamPeerBuffer, s: String) -> void:
	b.put_data(s.to_ascii_buffer())

static func _u32(v: int) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_u32(v)
	return b.data_array

static func _chunk(id: String, data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(id.to_ascii_buffer())
	out.append_array(_u32(data.size()))
	out.append_array(data)
	if data.size() % 2 == 1:
		out.append(0)
	return out

static func _list(kind: String, data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array("LIST".to_ascii_buffer())
	out.append_array(_u32(data.size() + 4))
	out.append_array(kind.to_ascii_buffer())
	out.append_array(data)
	return out
