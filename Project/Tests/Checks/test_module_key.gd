extends SceneTree
## M1 验收：哈希稳定性、量化规则、策略与尺寸关系、模块目录完整性。
## 运行：godot --headless --path Project --script res://Tests/Checks/test_module_key.gd

const Registry = preload("res://addons/ancient_building/core/module_registry.gd")
const KeyHelper = preload("res://addons/ancient_building/core/module_key.gd")
const Quantize = preload("res://addons/ancient_building/core/quantize.gd")

const EXPECTED_LAYERS := {
	"Base": 14,
	"Frame": 15,
	"Wall": 9,
	"Opening": 12,
	"Roof": 18,
	"Ornament": 3,
}

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_sha1_vectors()
	_test_canonical_form()
	_test_quantization()
	_test_policy_and_dims()
	_test_identity_inputs()
	_test_registry()

	if _failures == 0:
		print("PASS: module key and registry (%d checks)" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("ok   %s" % label)
	else:
		_failures += 1
		printerr("FAIL %s" % label)


func _test_sha1_vectors() -> void:
	_check(ModuleKey.sha1_hex("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d", "sha1('abc') matches the known vector")
	_check(ModuleKey.sha1_hex("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709", "sha1('') matches the known vector")


func _test_canonical_form() -> void:
	var a := {"b": 2, "a": [1, true]}
	var b := {"a": [1, true], "b": 2}
	_check(ModuleKey.canonicalize(a) == '{"a":[1,true],"b":2}', "canonical form sorts keys and drops whitespace")
	_check(ModuleKey.canonicalize(a) == ModuleKey.canonicalize(b), "dictionary insertion order does not change the canonical form")


func _test_quantization() -> void:
	var low := Quantize.length(2.4999)
	var mid := Quantize.length(2.5001)
	var high := Quantize.length(2.5030)
	_check(low == mid, "sub-millimetre difference quantizes to the same integer")
	_check(low != high, "millimetre difference quantizes to a different integer")

	var key_low := KeyHelper.make("F01", {"height": low}, "M_Default", 0)
	var key_mid := KeyHelper.make("F01", {"height": mid}, "M_Default", 0)
	var key_high := KeyHelper.make("F01", {"height": high}, "M_Default", 0)
	_check(key_low == key_mid, "same quantized params produce the same key")
	_check(key_low != key_high, "different quantized params produce a different key")


func _test_policy_and_dims() -> void:
	var params := {"height": Quantize.length(3.0), "thickness": Quantize.length(0.2)}
	var s_a := KeyHelper.make("F01", params, "M_Default", 0, {"width": 3000})
	var s_b := KeyHelper.make("F01", params, "M_Default", 0, {"width": 9000})
	_check(s_a == s_b, "S policy ignores resolved dims")

	var p_a := KeyHelper.make("R01", {"roof_type": 1}, "M_Default", 0, {"width": 3000})
	var p_b := KeyHelper.make("R01", {"roof_type": 1}, "M_Default", 0, {"width": 9000})
	_check(p_a != p_b, "P policy includes resolved dims")


func _test_identity_inputs() -> void:
	var params := {"height": Quantize.length(3.0)}
	var base := KeyHelper.make("F01", params, "M_Default", 0)
	_check(base.begins_with("ab1_"), "key carries the ab1_ prefix")
	_check(base.length() == 20, "key is prefix + 16 hex chars")
	_check(base != KeyHelper.make("F01", params, "M_Other", 0), "material set changes the key")
	_check(base != KeyHelper.make("F01", params, "M_Default", 1), "lod changes the key")
	_check(base != KeyHelper.make("W01", params, "M_Default", 0), "module id changes the key")


func _test_registry() -> void:
	var errors: Array = Registry.errors()
	_check(errors.is_empty(), "catalog loads without errors (%s)" % str(errors))
	_check(Registry.count() == 71, "catalog holds 71 modules (got %d)" % Registry.count())
	_check(Registry.generator_version() == 1, "generator_version is 1")

	for layer in EXPECTED_LAYERS:
		var actual := Registry.modules_in_layer(layer).size()
		_check(actual == EXPECTED_LAYERS[layer], "%s layer holds %d modules (got %d)" % [layer, EXPECTED_LAYERS[layer], actual])

	var ids: Array = Registry.all_ids()
	_check(ids.size() == 71, "all_ids returns 71 entries")
	var seen: Dictionary = {}
	var duplicates := 0
	for id in ids:
		if seen.has(id):
			duplicates += 1
		seen[id] = true
	_check(duplicates == 0, "no duplicate module ids")
