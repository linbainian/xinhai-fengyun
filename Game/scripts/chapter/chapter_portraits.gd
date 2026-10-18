class_name ChapterPortraits
extends RefCounted

const CATALOG_PATH: String = "res://data/portraits/characters.json"

static var _loaded: bool = false
static var _speakers: Dictionary[String, String] = {}
static var _textures: Dictionary[String, Texture2D] = {}


static func _load_catalog() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		push_error("Dialogue portrait catalog is not a dictionary: " + CATALOG_PATH)
		return
	var characters: Dictionary = parsed.get("characters", {})
	for id: String in characters:
		var entry: Dictionary = characters[id]
		var path: String = String(entry.get("texture", ""))
		for speaker: String in entry.get("speakers", []):
			_speakers[speaker] = path


static func texture_for(speaker: String) -> Texture2D:
	_load_catalog()
	if not _speakers.has(speaker):
		return null
	var path: String = _speakers[speaker]
	if not _textures.has(path):
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_error("Missing dialogue portrait for %s: %s" % [speaker, path])
			return null
		_textures[path] = texture
	return _textures[path]


static func has_speaker(speaker: String) -> bool:
	_load_catalog()
	return _speakers.has(speaker)


static func speakers() -> Array[String]:
	_load_catalog()
	var result: Array[String] = []
	result.assign(_speakers.keys())
	result.sort()
	return result
