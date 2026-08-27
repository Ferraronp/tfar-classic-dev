/*
	Name: TFAR_fnc_getLrProtectionCode

	Parameters:
		0: ARRAY [OBJECT, qualifier] - LR radio.
		1: SCALAR - Zero-based channel slot.
		Legacy flattened form [OBJECT, qualifier, channel] is also accepted.

	Returns:
		STRING - Three-digit NET code, or an empty string for an invalid slot.
*/
private ["_radio", "_radioObject", "_qualifier", "_channel", "_settings", "_codes"];
if (typeName (_this select 0) == "ARRAY") then {
	_radio = _this select 0;
	if ((count _radio) >= 2) then {
		_radioObject = _radio select 0;
		_qualifier = _radio select 1;
		_channel = _this select 1;
	};
} else {
	_radioObject = _this select 0;
	_qualifier = _this select 1;
	_channel = _this select 2;
};
if (isNil "_radioObject") exitWith {""};

if ((typeName _channel != "SCALAR") or {_channel != floor _channel} or {_channel < 0}) exitWith {""};
_settings = [_radioObject, _qualifier] call TFAR_fnc_getLrSettings;
if ((typeName _settings != "ARRAY") or {(count _settings) <= TF_PROTECTION_CODES_OFFSET}) exitWith {""};
if (isNil {_settings select TF_PROTECTION_CODES_OFFSET}) exitWith {""};
_codes = _settings select TF_PROTECTION_CODES_OFFSET;
if (typeName _codes != "ARRAY") exitWith {""};
if (_channel >= count _codes) exitWith {""};
if (isNil {_codes select _channel}) exitWith {""};
if (typeName (_codes select _channel) != "STRING") exitWith {""};
_codes select _channel
