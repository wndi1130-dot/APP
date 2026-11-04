extends Node
## 측정용(합치지 않음, 폰 N13b): 100 ms 넘는 장마다, 또는 파이프라인 컴파일이 생긴 장마다
## 그 사이 바뀐 것(파이프라인 컴파일·객체·자원·노드 수·비디오 메모리)과 처리·렌더 CPU/GPU ms를 한 줄로 찍는다.

const LONG_MS: float = 100.0

var _counters: Dictionary = {}
var _prev: Dictionary = {}
var _last_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: String in ["CANVAS", "MESH", "SURFACE", "DRAW", "SPECIALIZATION"]:
		var key: String = "RENDERING_INFO_PIPELINE_COMPILATIONS_" + n
		if ClassDB.class_has_integer_constant("RenderingServer", key):
			_counters[n] = ClassDB.class_get_integer_constant("RenderingServer", key)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_prev = _snap()
	_last_usec = Time.get_ticks_usec()
	print("FRAME_WATCH ", {"counters": _counters.keys(), "msec": Time.get_ticks_msec()})


func _snap() -> Dictionary:
	var s: Dictionary = {}
	for n: String in _counters:
		s["pipe_" + n.to_lower()] = float(RenderingServer.get_rendering_info(_counters[n]))
	s["objects"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	s["resources"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	s["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	s["vmem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	return s


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	var s: Dictionary = _snap()
	var diff: Dictionary = {}
	var piped: bool = false
	for k: String in s:
		var was: float = float(_prev.get(k, 0.0))
		var is_now: float = float(s[k])
		if is_now != was:
			diff[k] = snappedf(is_now - was, 0.1)
			if k.begins_with("pipe_"):
				piped = true
	if dt > LONG_MS or piped:
		var vp: RID = get_viewport().get_viewport_rid()
		print("LONG_FRAME ", {"ms": snappedf(dt, 0.1), "msec": Time.get_ticks_msec(), "frame": Engine.get_process_frames(),
			"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
			"render_cpu_ms": snappedf(RenderingServer.viewport_get_measured_render_time_cpu(vp), 0.1),
			"render_gpu_ms": snappedf(RenderingServer.viewport_get_measured_render_time_gpu(vp), 0.1),
			"diff": diff})
	_prev = s
