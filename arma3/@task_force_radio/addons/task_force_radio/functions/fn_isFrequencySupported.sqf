/*
	Name: TFAR_fnc_isFrequencySupported

	Parameters:
		0: ARRAY - Radio capabilities.
		1: SCALAR - Canonical frequency in kHz.

	Returns:
		BOOLEAN - Whether the frequency belongs to the device band and grid.
*/
private ["_capabilities", "_frequencyKhz", "_minimumKhz", "_maximumKhz", "_stepKhz"];
_capabilities = _this select 0;
_frequencyKhz = _this select 1;

if ((typeName _capabilities != "ARRAY") or {(count _capabilities) < 4}) exitWith {false};
if (typeName _frequencyKhz != "SCALAR") exitWith {false};

_minimumKhz = _capabilities select TFAR_CAP_MIN_KHZ_OFFSET;
_maximumKhz = _capabilities select TFAR_CAP_MAX_KHZ_OFFSET;
_stepKhz = _capabilities select TFAR_CAP_STEP_KHZ_OFFSET;

(typeName _minimumKhz == "SCALAR")
	and {typeName _maximumKhz == "SCALAR"}
	and {typeName _stepKhz == "SCALAR"}
	and {_minimumKhz >= 0}
	and {_maximumKhz >= _minimumKhz}
	and {_stepKhz > 0}
	and {_frequencyKhz >= _minimumKhz}
	and {_frequencyKhz <= _maximumKhz}
	and {((_frequencyKhz - _minimumKhz) mod _stepKhz) == 0}
