/*
	Name: TFAR_fnc_getSwProtectionCode

	Parameters:
		0: STRING - SW radio classname.
		1: SCALAR - Zero-based channel slot.

	Returns:
		STRING - Three-digit NET code, or an empty string for an invalid slot.
*/
private ["_radio", "_channel", "_settings", "_codes"];
_radio = _this select 0;
_channel = _this select 1;

if (typeName _radio != "STRING") exitWith {""};
if ((typeName _channel != "SCALAR") or {_channel != floor _channel} or {_channel < 0}) exitWith {""};
_settings = _radio call TFAR_fnc_getSwSettings;
if ((typeName _settings != "ARRAY") or {(count _settings) <= TF_PROTECTION_CODES_OFFSET}) exitWith {""};
if (isNil {_settings select TF_PROTECTION_CODES_OFFSET}) exitWith {""};
_codes = _settings select TF_PROTECTION_CODES_OFFSET;
if (typeName _codes != "ARRAY") exitWith {""};
if (_channel >= count _codes) exitWith {""};
if (isNil {_codes select _channel}) exitWith {""};
if (typeName (_codes select _channel) != "STRING") exitWith {""};
_codes select _channel
