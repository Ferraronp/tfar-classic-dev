private["_depth", "_radio", "_command"];
if (time - TF_last_lr_tangent_press > 0.5) then {
	if (!(TF_tangent_sw_pressed) and {alive TFAR_currentUnit} and {call TFAR_fnc_haveSWRadio}) then {	
		if (call TFAR_fnc_isAbleToUseRadio) then {
			call TFAR_fnc_unableToUseHint;
		} else {
			_depth = TFAR_currentUnit call TFAR_fnc_eyeDepth;
			if ([TFAR_currentUnit, TFAR_currentUnit call TFAR_fnc_vehicleIsIsolatedAndInside, [TFAR_currentUnit call TFAR_fnc_vehicleIsIsolatedAndInside, _depth] call TFAR_fnc_canSpeak, _depth] call TFAR_fnc_canUseSWRadio) then {
				_radio = call TFAR_fnc_activeSwRadio;
				_command = ["TANGENT", "PRESSED", _radio, _radio call TFAR_fnc_getSwChannel, call TFAR_fnc_currentSWFrequency, getNumber(configFile >> "CfgWeapons" >> _radio >> "tf_range") * (call TFAR_fnc_getTransmittingDistanceMultiplicator), getText(configFile >> "CfgWeapons" >> _radio >> "tf_subtype")] call TFAR_fnc_buildRadioTangentCommand;
				if (_command != "") then {
					["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 0, false, true]] call TFAR_fnc_fireEventHandlers;
					[format[localize "STR_transmit",format ["%1<img size='1.5' image='%2'/>", getText (ConfigFile >> "CfgWeapons" >> _radio >> "displayName"),
						getText(configFile >> "CfgWeapons"  >> _radio >> "picture")],(_radio call TFAR_fnc_getSwChannel) + 1, call TFAR_fnc_currentSWFrequency], _command, -1] call TFAR_fnc_ProcessTangent;
					TF_tangent_sw_pressed = true;
					["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 0, false, true]] call TFAR_fnc_fireEventHandlers;
				};
			} else {
				call TFAR_fnc_inWaterHint;
			};
		};
	};
};
true
