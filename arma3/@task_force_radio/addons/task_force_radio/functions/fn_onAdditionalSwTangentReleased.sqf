private ["_freq", "_command", "_mode"];
if ((TF_tangent_sw_pressed) and {alive TFAR_currentUnit}) then {
	private "_radio";
	_radio = call TFAR_fnc_activeSwRadio;
	if ((_radio call TFAR_fnc_getAdditionalSwChannel) > -1) then {
		_freq = [_radio, (_radio call TFAR_fnc_getAdditionalSwChannel) + 1] call TFAR_fnc_GetChannelFrequency;
		_command = ["TANGENT", "RELEASED", _radio, _radio call TFAR_fnc_getAdditionalSwChannel, _freq, getNumber(configFile >> "CfgWeapons" >> _radio >> "tf_range") * (call TFAR_fnc_getTransmittingDistanceMultiplicator), getText(configFile >> "CfgWeapons" >> _radio >> "tf_subtype")] call TFAR_fnc_buildRadioTangentCommand;
		if (_command != "") then {
			["OnBeforeTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 0, true, false]] call TFAR_fnc_fireEventHandlers;
			[format[localize "STR_additional_transmit_end",format ["%1<img size='1.5' image='%2'/>", getText (ConfigFile >> "CfgWeapons" >> _radio >> "displayName"), getText(configFile >> "CfgWeapons"  >> _radio >> "picture")], (_radio call TFAR_fnc_getAdditionalSwChannel) + 1,  _freq], _command] call TFAR_fnc_ProcessTangent;
			["OnTangent", TFAR_currentUnit, [TFAR_currentUnit, _radio, 0, true, false]] call TFAR_fnc_fireEventHandlers;
		};
	} else {
		_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
		if ((typeName _mode == "STRING") and {(toUpper _mode) in ["OPEN", "KEYED"]}) then {
			_command = ["TANGENT", "RELEASED", _radio, 0, "", 0, "digital"] call TFAR_fnc_buildRadioTangentCommand;
			if ((_command != "") and {isMultiplayer}) then {
				"task_force_radio_pipe" callExtension _command;
			};
		};
	};
	TF_tangent_sw_pressed = false;
};
false
