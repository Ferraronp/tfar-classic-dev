/*
	Name: TFAR_fnc_onCurrentUnitChanged

	Author(s):
		NKey
		TFAR Classic contributors

	Description:
		Updates the unit used as the local voice/listener origin when Zeus remote
		control or respawn changes the current unit. The controlled unit is
		published for other clients and any active transmission is stopped before
		the switch.

	Parameters:
		0: OBJECT - New current unit
		1: OBJECT - Previous current unit (optional, used for documentation only)

	Returns:
		BOOLEAN - True when the current unit changed

	Example:
		[_newUnit, _oldUnit] call TFAR_fnc_onCurrentUnitChanged;
*/
private ["_newUnit", "_oldUnit", "_changed", "_mode", "_useV2", "_command"];

_newUnit = if ((count _this) > 0) then {_this select 0} else {call TFAR_fnc_currentUnit};
if (isNull _newUnit) then {
	_newUnit = player;
};

_oldUnit = missionNamespace getVariable ["TFAR_currentUnit", player];
_changed = _newUnit != _oldUnit;
_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {_mode = "Legacy"};
_useV2 = (toUpper _mode) in ["OPEN", "KEYED"];

if (_changed) then {
	// Release against the old unit while its inventory and radio settings are
	// still available. The direct fallbacks also clear the plugin when the old
	// unit died or was deleted before the key-up event arrived.
	if (!(isNil "TF_tangent_sw_pressed") and {TF_tangent_sw_pressed}) then {
		if (alive _oldUnit) then {
			call TFAR_fnc_onSwTangentReleased;
		};
		if (TF_tangent_sw_pressed) then {
			if (isMultiplayer) then {
				_command = "";
				if (_useV2) then {
					_command = ["TANGENT", "RELEASED", objNull, 0, "", 0, "digital"] call TFAR_fnc_buildRadioTangentCommand;
				};
				if (_command == "") then {_command = "TANGENT	RELEASED	No_SW_Radio	0	digital"};
				"task_force_radio_pipe" callExtension _command;
			};
			TF_tangent_sw_pressed = false;
		};
	};

	if (!(isNil "TF_tangent_lr_pressed") and {TF_tangent_lr_pressed}) then {
		if (alive _oldUnit) then {
			call TFAR_fnc_onLRTangentReleased;
		};
		if (TF_tangent_lr_pressed) then {
			if (isMultiplayer) then {
				_command = "";
				if (_useV2) then {
					_command = ["TANGENT_LR", "RELEASED", [], 0, "", 0, "digital_lr"] call TFAR_fnc_buildRadioTangentCommand;
				};
				if (_command == "") then {_command = "TANGENT_LR	RELEASED	No_LR_Radio	0	digital_lr"};
				"task_force_radio_pipe" callExtension _command;
			};
			TF_tangent_lr_pressed = false;
		};
	};

	if (!(isNil "TF_tangent_dd_pressed") and {TF_tangent_dd_pressed}) then {
		if (alive _oldUnit) then {
			call TFAR_fnc_onDDTangentReleased;
		};
		if (TF_tangent_dd_pressed) then {
			if (isMultiplayer) then {
				_command = "";
				if (_useV2) then {
					_command = ["TANGENT_DD", "RELEASED", "DD", 0, TF_dd_frequency, 0, "dd"] call TFAR_fnc_buildRadioTangentCommand;
				};
				if (_command == "") then {_command = "TANGENT_DD	RELEASED	No_DD_Radio	0	dd"};
				"task_force_radio_pipe" callExtension _command;
			};
			TF_tangent_dd_pressed = false;
		};
	};

	if (isMultiplayer) then {
		"task_force_radio_pipe" callExtension (format ["RELEASE_ALL_TANGENTS	%1", name player]);
	};

	// Hide the SW radio until duplicate-instance normalisation completes.
	// Copying a loadout can give both units the exact same radio classname.
	TFAR_currentUnitRadioReady = false;
	TFAR_currentUnit = _newUnit;

	// Force position and frequency data to be rebuilt from the new point of
	// view instead of finishing a queue calculated around the previous unit.
	tf_nearPlayers = [];
	tf_farPlayers = [];
	tf_nearPlayersIndex = 0;
	tf_farPlayersIndex = 0;
	tf_nearPlayersProcessed = true;
	tf_farPlayersProcessed = true;
	tf_speakerRadios = [];
	tf_lastNearPlayersUpdate = 0;
	tf_lastFrequencyInfoTick = 0;

	// Run radio-instance normalisation immediately on a unit switch. The
	// regular polling loop is throttled, which otherwise leaves a short window
	// where two units can still share the same SW settings.
	[_newUnit] spawn {
		private "_unit";
		_unit = _this select 0;
		waitUntil {
			sleep 0.05;
			!(missionNamespace getVariable ["TF_radio_request_mutex", false]) or {TFAR_currentUnit != _unit}
		};
		if ((TFAR_currentUnit == _unit) and {alive _unit}) then {
			[false, true] call TFAR_fnc_requestRadios;
		};
		if (TFAR_currentUnit == _unit) then {
			TFAR_currentUnitRadioReady = true;
		};
	};
};

// Other clients use this variable to place the TeamSpeak voice at the
// controlled unit. Update it for A -> B switches too, not only enter/exit.
if (_newUnit != player) then {
	if ((player getVariable ["tf_controlled_unit", objNull]) != _newUnit) then {
		player setVariable ["tf_controlled_unit", _newUnit, true];
	};
} else {
	player setVariable ["tf_controlled_unit", nil, true];
};

_changed
