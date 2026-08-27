/*
 	Name: TFAR_fnc_setSwRadioCode
 	
 	Author(s):
		L-H
 	
 	Description:
		Allows setting of the encryption code for individual radios.
 	
 	Parameters: 
		0: STRING - Radio classname
		1: STRING - Encryption code.
 	
 	Returns:
		Nothing
 	
 	Example:
		[call TFAR_fnc_activeSwRadio, "NewEncryptionCode"] call TFAR_fnc_setSwRadioCode;
*/
private ["_settings", "_radio_id", "_code_to_set", "_mode", "_channel"];
_radio_id = _this select 0;
_code_to_set = _this select 1;
_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {
	_mode = "Legacy";
};

switch (toUpper _mode) do {
	case "OPEN": {
		if !(missionNamespace getVariable ["TFAR_radioCodeCompatibilityWarningShown", false]) then {
			diag_log "TFAR WARNING: legacy RadioCode setter ignored in Open mode; use the per-channel ProtectionCode API.";
			missionNamespace setVariable ["TFAR_radioCodeCompatibilityWarningShown", true];
		};
	};
	case "KEYED": {
		if !(missionNamespace getVariable ["TFAR_radioCodeCompatibilityWarningShown", false]) then {
			diag_log "TFAR WARNING: legacy RadioCode setter is deprecated in Keyed mode; use the per-channel ProtectionCode API.";
			missionNamespace setVariable ["TFAR_radioCodeCompatibilityWarningShown", true];
		};
		_channel = _radio_id call TFAR_fnc_getSwChannel;
		[_radio_id, _channel, _code_to_set] call TFAR_fnc_setSwProtectionCode;
	};
	default {
		_settings = _radio_id call TFAR_fnc_getSwSettings;
		_settings set [TF_CODE_OFFSET, _code_to_set];
		[_radio_id, _settings] call TFAR_fnc_setSwSettings;
	};
};
