/*
 	Name: TFAR_fnc_getSwRadioCode
 	
 	Author(s):
		NKey
		L-H
 	
 	Description:
		Returns the encryption code for the passed radio.
 	
 	Parameters: 
 	0: STRING - Radio classname
 	
 	Returns:
	STRING - Encryption code
 	
	Example:
	(call TFAR_fnc_activeSwRadio) call TFAR_fnc_getSwRadioCode;
*/
private ["_mode", "_channel"];
_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {
	_mode = "Legacy";
};

switch (toUpper _mode) do {
	case "OPEN": {""};
	case "KEYED": {
		_channel = _this call TFAR_fnc_getSwChannel;
		[_this, _channel] call TFAR_fnc_getSwProtectionCode
	};
	default {
		((_this call TFAR_fnc_getSwSettings) select TF_CODE_OFFSET)
	};
}
