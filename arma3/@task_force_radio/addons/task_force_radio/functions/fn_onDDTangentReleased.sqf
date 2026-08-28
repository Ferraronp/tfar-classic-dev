private ["_command"];
if ((TF_tangent_dd_pressed) and {alive TFAR_currentUnit}) then {
	_command = ["TANGENT_DD", "RELEASED", "DD", 0, TF_dd_frequency, 0, "dd"] call TFAR_fnc_buildRadioTangentCommand;
	if (_command != "") then {
		["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, "DD", 2, false, false]] call TFAR_fnc_fireEventHandlers;
		[format[localize "STR_transmit_end", "DD", "1", TF_dd_frequency], _command] call TFAR_fnc_ProcessTangent;
		["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, "DD", 2, false, false]] call TFAR_fnc_fireEventHandlers;
	};
	TF_tangent_dd_pressed = false;
};
true
