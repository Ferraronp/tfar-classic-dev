/*
	Name: TFAR_fnc_setSwProtectionCode

	Parameters:
		0: STRING - SW radio classname.
		1: SCALAR - Zero-based channel slot.
		2: STRING - Three-digit NET code.

	Returns:
		BOOLEAN - Whether the value was applied.
*/
private ["_radio", "_channel", "_code", "_settings", "_codes"];
_radio = _this select 0;
_channel = _this select 1;
_code = _this select 2;

if (typeName _radio != "STRING") exitWith {false};
if (!(_code call TFAR_fnc_isValidProtectionCode)) exitWith {false};
if ((typeName _channel != "SCALAR") or {_channel != floor _channel} or {_channel < 0}) exitWith {false};

_settings = _radio call TFAR_fnc_getSwSettings;
if ((typeName _settings != "ARRAY") or {(count _settings) <= TF_PROTECTION_CODES_OFFSET}) exitWith {false};
if (isNil {_settings select TF_PROTECTION_CODES_OFFSET}) exitWith {false};
if (typeName (_settings select TF_PROTECTION_CODES_OFFSET) != "ARRAY") exitWith {false};
_codes = +(_settings select TF_PROTECTION_CODES_OFFSET);
if (_channel >= count _codes) exitWith {false};

_codes set [_channel, _code];
_settings set [TF_PROTECTION_CODES_OFFSET, _codes];
[_radio, _settings] call TFAR_fnc_setSwSettings;
true
