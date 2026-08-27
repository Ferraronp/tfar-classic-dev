/*
	Name: TFAR_fnc_setLrProtectionCode

	Parameters:
		0: ARRAY [OBJECT, qualifier] - LR radio.
		1: SCALAR - Zero-based channel slot.
		2: STRING - Three-digit NET code.
		Legacy flattened form [OBJECT, qualifier, channel, code] is also accepted.

	Returns:
		BOOLEAN - Whether the value was applied.
*/
private ["_radio", "_radioObject", "_qualifier", "_channel", "_code", "_settings", "_codes"];
if (typeName (_this select 0) == "ARRAY") then {
	_radio = _this select 0;
	if ((count _radio) >= 2) then {
		_radioObject = _radio select 0;
		_qualifier = _radio select 1;
		_channel = _this select 1;
		_code = _this select 2;
	};
} else {
	_radioObject = _this select 0;
	_qualifier = _this select 1;
	_channel = _this select 2;
	_code = _this select 3;
};
if (isNil "_radioObject") exitWith {false};

if (!(_code call TFAR_fnc_isValidProtectionCode)) exitWith {false};
if ((typeName _channel != "SCALAR") or {_channel != floor _channel} or {_channel < 0}) exitWith {false};

_settings = [_radioObject, _qualifier] call TFAR_fnc_getLrSettings;
if ((typeName _settings != "ARRAY") or {(count _settings) <= TF_PROTECTION_CODES_OFFSET}) exitWith {false};
if (isNil {_settings select TF_PROTECTION_CODES_OFFSET}) exitWith {false};
if (typeName (_settings select TF_PROTECTION_CODES_OFFSET) != "ARRAY") exitWith {false};
_codes = +(_settings select TF_PROTECTION_CODES_OFFSET);
if (_channel >= count _codes) exitWith {false};

_codes set [_channel, _code];
_settings set [TF_PROTECTION_CODES_OFFSET, _codes];
[_radioObject, _qualifier, _settings] call TFAR_fnc_setLrSettings;
true
