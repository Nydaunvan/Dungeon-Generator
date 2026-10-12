class_name ProcMem
extends RefCounted
## Mémoire RAM réellement occupée par le jeu (en Mo), pour le compteur de performances.
## OS.get_static_memory_usage() renvoie 0 dans un export « release » : on interroge donc le système.
##   Linux : /proc/self/statm (instantané) · Windows : tasklist · macOS : ps (échantillonnés dans un fil, jamais sur le fil du jeu)
##   Navigateur : mémoire WebAssembly (HEAP8), à défaut le tas JavaScript (Chrome).
## Une valeur de 0 signifie « indisponible » (le compteur affiche alors « — »).

const PERIOD_MS := 3000

static var _mb := 0.0
static var _last := -PERIOD_MS
static var _thread: Thread = null

## Dernière valeur connue (Mo) ; lance au besoin un nouvel échantillonnage (au plus un toutes les 3 s).
static func mb() -> float:
	if OS.has_feature("web"):
		return _web_mb()
	if OS.get_name() == "Linux" or OS.get_name() == "FreeBSD":
		var f := FileAccess.open("/proc/self/statm", FileAccess.READ)
		if f != null:
			var parts := f.get_line().split(" ")
			if parts.size() > 1:
				_mb = float(parts[1].to_int()) * 4096.0 / 1048576.0
		return _mb
	var now := Time.get_ticks_msec()
	if now - _last >= PERIOD_MS and (_thread == null or not _thread.is_alive()):
		_last = now
		if _thread != null:
			_thread.wait_to_finish()
		_thread = Thread.new()
		_thread.start(_sample.bind(OS.get_process_id(), OS.get_name()))
	return _mb

static func _sample(pid: int, os_name: String) -> void:
	var out: Array = []
	if os_name == "Windows":
		var code := OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"], out, false, false)
		if code == 0 and out.size() > 0:
			_mb = parse_tasklist(str(out[0]))
	elif os_name == "macOS":
		var code := OS.execute("ps", ["-o", "rss=", "-p", str(pid)], out, false, false)
		if code == 0 and out.size() > 0:
			_mb = float(str(out[0]).strip_edges().to_int()) / 1024.0

## Ligne CSV de tasklist (« "x.exe","1234","Console","1","123 456 Ko" ») → Mo. Le séparateur de milliers dépend de la langue.
static func parse_tasklist(text: String) -> float:
	var line := text.strip_edges().split("\n")[0]
	var cols := line.split("\",\"")
	if cols.size() < 5:
		return 0.0
	var digits := ""
	for ch in cols[cols.size() - 1]:
		if ch >= "0" and ch <= "9":
			digits += ch
	return float(digits.to_int()) / 1024.0

static func _web_mb() -> float:
	var v: Variant = JavaScriptBridge.eval("(typeof HEAP8 !== 'undefined' && HEAP8.length) || (performance.memory ? performance.memory.usedJSHeapSize : 0)")
	return float(v) / 1048576.0 if v != null else 0.0
