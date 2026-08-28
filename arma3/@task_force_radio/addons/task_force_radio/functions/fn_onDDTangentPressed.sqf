private["_result", "_request", "_hintText", "_command"];
if (time - TF_last_dd_tangent_press > 0.1) then {
	if (!(TF_tangent_dd_pressed) and {alive TFAR_currentUnit} and {call TFAR_fnc_haveDDRadio}) then {
		if (call TFAR_fnc_isAbleToUseRadio) then {
			call TFAR_fnc_unableToUseHint;
		} else {
			if ([TFAR_currentUnit call TFAR_fnc_eyeDepth, TFAR_currentUnit call TFAR_fnc_vehicleIsIsolatedAndInside] call TFAR_fnc_canUseDDRadio) then {
				_command = ["TANGENT_DD", "PRESSED", "DD", 0, TF_dd_frequency, 0, "dd"] call TFAR_fnc_buildRadioTangentCommand;
				if (_command != "") then {
					["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, "DD", 2, false, true]] call TFAR_fnc_fireEventHandlers;
					[format[localize "STR_transmit", "DD", "1", TF_dd_frequency], _command, -1] call TFAR_fnc_ProcessTangent;
					TF_tangent_dd_pressed = true;
					["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, "DD", 2, false, true]] call TFAR_fnc_fireEventHandlers;
				};
			} else {
				call TFAR_fnc_onGroundHint;
			}
		};	
	};
};
TF_last_dd_tangent_press = time;
true
