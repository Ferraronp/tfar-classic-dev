private["_radio", "_command"];
if (time - TF_last_lr_tangent_press > 0.1) then {
	if (!(TF_tangent_lr_pressed) and {alive TFAR_currentUnit} and {call TFAR_fnc_haveLRRadio}) then {

		if (call TFAR_fnc_isAbleToUseRadio) then {
			call TFAR_fnc_unableToUseHint;
		} else {
			if ([TFAR_currentUnit, TFAR_currentUnit call TFAR_fnc_vehicleIsIsolatedAndInside, TFAR_currentUnit call TFAR_fnc_eyeDepth] call TFAR_fnc_canUseLRRadio) then {
				_radio = call TFAR_fnc_activeLrRadio;
				_command = ["TANGENT_LR", "PRESSED", _radio, _radio call TFAR_fnc_getLrChannel, call TFAR_fnc_currentLRFrequency, ([_radio select 0, "tf_range"] call TFAR_fnc_getLrRadioProperty) * (call TFAR_fnc_getTransmittingDistanceMultiplicator), [_radio select 0, "tf_subtype"] call TFAR_fnc_getLrRadioProperty] call TFAR_fnc_buildRadioTangentCommand;
				if (_command != "") then {
					["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 1, false, true]] call TFAR_fnc_fireEventHandlers;
					[format[localize "STR_transmit",format ["%1<img size='1.5' image='%2'/>",[_radio select 0, "displayName"] call TFAR_fnc_getLrRadioProperty,
						getText(configFile >> "CfgVehicles"  >> typeof (_radio select 0) >> "picture")],(_radio call TFAR_fnc_getLrChannel) + 1, call TFAR_fnc_currentLRFrequency], _command, -1] call TFAR_fnc_ProcessTangent;
					TF_tangent_lr_pressed = true;
					["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 1, false, true]] call TFAR_fnc_fireEventHandlers;
				};
			} else {
				call TFAR_fnc_inWaterHint;
			}
		};
	};
};
TF_last_lr_tangent_press = time;
true
