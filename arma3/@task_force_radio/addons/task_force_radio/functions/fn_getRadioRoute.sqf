/*
	Name: TFAR_fnc_getRadioRoute

	Description:
		Builds the canonical route tuple used by protocol v2.

	Parameters:
		0: STRING SW radio, or ARRAY [OBJECT, qualifier] LR radio.
		1: SCALAR - Zero-based channel slot.

	Returns:
		ARRAY [waveform, frequencyKhz, protectionCode, talkGroup], or [] when invalid.
*/
private ["_radio", "_channel", "_isLr", "_settings", "_frequencies", "_talkGroups", "_frequency", "_frequencyKhz", "_capabilities", "_code", "_talkGroup"];
_radio = _this select 0;
_channel = _this select 1;
_isLr = typeName _radio == "ARRAY";

if ((typeName _channel != "SCALAR") or {_channel != floor _channel} or {_channel < 0}) exitWith {[]};
if (!_isLr and {typeName _radio != "STRING"}) exitWith {[]};
if (_isLr and {(count _radio) < 2}) exitWith {[]};

if (_isLr) then {
	_settings = _radio call TFAR_fnc_getLrSettings;
} else {
	_settings = _radio call TFAR_fnc_getSwSettings;
};
if (typeName _settings != "ARRAY") exitWith {[]};
if ((count _settings) <= TF_FREQ_OFFSET) exitWith {[]};
if (isNil {_settings select TF_FREQ_OFFSET}) exitWith {[]};
_frequencies = _settings select TF_FREQ_OFFSET;
if (typeName _frequencies != "ARRAY") exitWith {[]};
if (_channel >= count _frequencies) exitWith {[]};
if (isNil {_frequencies select _channel}) exitWith {[]};

_frequency = _frequencies select _channel;
_frequencyKhz = _frequency call TFAR_fnc_normalizeFrequencyKhz;
_capabilities = _radio call TFAR_fnc_getRadioCapabilities;
if (!([_capabilities, _frequencyKhz] call TFAR_fnc_isFrequencySupported)) exitWith {[]};

if (_isLr) then {
	_code = [_radio, _channel] call TFAR_fnc_getLrProtectionCode;
} else {
	_code = [_radio, _channel] call TFAR_fnc_getSwProtectionCode;
};

if (!(_code call TFAR_fnc_isValidProtectionCode)) exitWith {[]};
if ((count _settings) <= TF_TALK_GROUPS_OFFSET) exitWith {[]};
if (isNil {_settings select TF_TALK_GROUPS_OFFSET}) exitWith {[]};
_talkGroups = _settings select TF_TALK_GROUPS_OFFSET;
if (typeName _talkGroups != "ARRAY") exitWith {[]};
if (_channel >= count _talkGroups) exitWith {[]};
if (isNil {_talkGroups select _channel}) exitWith {[]};
_talkGroup = _talkGroups select _channel;
if ((typeName _talkGroup != "SCALAR") or {_talkGroup != TFAR_DEFAULT_TALK_GROUP}) exitWith {[]};

[_capabilities select TFAR_CAP_WAVEFORM_OFFSET, _frequencyKhz, _code, _talkGroup]
