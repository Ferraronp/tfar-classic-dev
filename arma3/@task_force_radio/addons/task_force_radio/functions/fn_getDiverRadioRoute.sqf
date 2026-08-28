/* Builds the fixed protocol-v2 route for the diver radio. */
private ["_frequencyKhz"];
_frequencyKhz = TF_dd_frequency call TFAR_fnc_normalizeFrequencyKhz;
if ((typeName _frequencyKhz != "SCALAR")
	or {_frequencyKhz < (TF_MIN_DD_FREQ * 1000)}
	or {_frequencyKhz > (TF_MAX_DD_FREQ * 1000)}
	or {((_frequencyKhz - (TF_MIN_DD_FREQ * 1000)) mod TFAR_DEFAULT_FREQUENCY_STEP_KHZ) != 0}) exitWith {[]};

["tfar_dd", _frequencyKhz, TFAR_DEFAULT_PROTECTION_CODE, TFAR_DEFAULT_TALK_GROUP]
