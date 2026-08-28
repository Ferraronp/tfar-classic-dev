private ["_radio", "_command"];
if ((TF_tangent_lr_pressed) and {alive TFAR_currentUnit}) then {
	_radio = call TFAR_fnc_activeLrRadio;
	
	_command = ["TANGENT_LR", "RELEASED", _radio, _radio call TFAR_fnc_getLrChannel, call TFAR_fnc_currentLRFrequency, ([_radio select 0, "tf_range"] call TFAR_fnc_getLrRadioProperty) * (call TFAR_fnc_getTransmittingDistanceMultiplicator), [_radio select 0, "tf_subtype"] call TFAR_fnc_getLrRadioProperty] call TFAR_fnc_buildRadioTangentCommand;
	if (_command != "") then {
		["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 1, false, false]] call TFAR_fnc_fireEventHandlers;
		[format[localize "STR_transmit_end",format ["%1<img size='1.5' image='%2'/>",[_radio select 0, "displayName"] call TFAR_fnc_getLrRadioProperty,
			getText(configFile >> "CfgVehicles"  >> typeof (_radio select 0) >> "picture")],(_radio call TFAR_fnc_getLrChannel) + 1, call TFAR_fnc_currentLRFrequency], _command] call TFAR_fnc_ProcessTangent;
		["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 1, false, false]] call TFAR_fnc_fireEventHandlers;
	};
	TF_tangent_lr_pressed = false;
};

true
