private ["_radio", "_command"];
if ((TF_tangent_sw_pressed) and {alive TFAR_currentUnit}) then {
	_radio = call TFAR_fnc_activeSwRadio;
	
	_command = ["TANGENT", "RELEASED", _radio, _radio call TFAR_fnc_getSwChannel, call TFAR_fnc_currentSWFrequency, getNumber(configFile >> "CfgWeapons" >> _radio >> "tf_range") * (call TFAR_fnc_getTransmittingDistanceMultiplicator), getText(configFile >> "CfgWeapons" >> _radio >> "tf_subtype")] call TFAR_fnc_buildRadioTangentCommand;
	if (_command != "") then {
		["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 0, false, false]] call TFAR_fnc_fireEventHandlers;
		[format[localize "STR_transmit_end",format ["%1<img size='1.5' image='%2'/>", getText (ConfigFile >> "CfgWeapons" >> _radio >> "displayName"),
			getText(configFile >> "CfgWeapons"  >> _radio >> "picture")],(_radio call TFAR_fnc_getSwChannel) + 1, call TFAR_fnc_currentSWFrequency], _command] call TFAR_fnc_ProcessTangent;
		["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 0, false, false]] call TFAR_fnc_fireEventHandlers;
	};
	TF_tangent_sw_pressed = false;
};
true
