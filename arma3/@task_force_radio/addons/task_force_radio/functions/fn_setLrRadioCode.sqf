/*
 	Name: TFAR_fnc_setLrRadioCode
 	
 	Author(s):
		L-H
 	
 	Description:
		Allows setting of the encryption code for individual radios.
 	
 	Parameters:
		
 	
 	Returns:
		Nothing
 	
 	Example:
		[(call TFAR_fnc_activeLrRadio) select 0, (call TFAR_fnc_activeLrRadio) select 1, "NewEncryptionCode"] call TFAR_fnc_setLrRadioCode;
*/
#include "script.h"
private ["_radio_object", "_radio_qualifier", "_value", "_settings", "_mode", "_channel"];
_radio_object = _this select 0;
_radio_qualifier = _this select 1;
_value = _this select 2;
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
		_channel = [_radio_object, _radio_qualifier] call TFAR_fnc_getLrChannel;
		[[_radio_object, _radio_qualifier], _channel, _value] call TFAR_fnc_setLrProtectionCode;
	};
	default {
		_settings = [_radio_object, _radio_qualifier] call TFAR_fnc_getLrSettings;
		_settings set [TF_CODE_OFFSET, _value];
		[_radio_object, _radio_qualifier, _settings] call TFAR_fnc_setLrSettings;
	};
};
