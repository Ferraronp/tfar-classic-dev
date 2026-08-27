/*
 	Name: TFAR_fnc_getLrRadioCode
 	
 	Author(s):
		NKey
		L-H
 	
 	Description:
		Returns the encryption code for the passed radio.
 	
 	Parameters: 
 	0: OBJECT - Radio
 	
 	Returns:
	STRING - Encryption code
 	
	Example:
	(call TFAR_fnc_activeLrRadio) call TFAR_fnc_getLrRadioCode;
*/
private ["_mode", "_channel"];
_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {
	_mode = "Legacy";
};

switch (toUpper _mode) do {
	case "OPEN": {""};
	case "KEYED": {
		_channel = _this call TFAR_fnc_getLrChannel;
		[_this, _channel] call TFAR_fnc_getLrProtectionCode
	};
	default {
		((_this call TFAR_fnc_getLrSettings) select TF_CODE_OFFSET)
	};
}
