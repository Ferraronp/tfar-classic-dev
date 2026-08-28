/*
 	Name: TFAR_fnc_sendFrequencyInfo
 	
 	Author(s):
		NKey

 	Description:
		Notifies the plugin about the radios currently being used by the player and various settings active on the radio.
	
	Parameters:
		Nothing
 	
 	Returns:
		Nothing
 	
 	Example:
		call TFAR_fnc_sendFrequencyInfo;
*/

private ["_request","_result","_freq","_freq_lr","_freq_dd","_alive","_nickname","_isolated_and_inside","_can_speak","_depth","_globalVolume", "_voiceVolume", "_spectator", "_receivingDistanceMultiplicator", "_radios", "_mode", "_useV2", "_routeCapable", "_channel", "_additional", "_entry", "_route"];

// send frequencies
_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {_mode = "Legacy"};
_useV2 = (toUpper _mode) in ["OPEN", "KEYED"];
_routeCapable = _useV2 and {"radio_route_v2" call TFAR_fnc_hasPluginProtocolCapability};

if (_useV2) then {
	_freq = [];
	_freq_lr = [];
	_freq_dd = "-";
} else {
	_freq = ["No_SW_Radio"];
	_freq_lr = ["No_LR_Radio"];
	_freq_dd = "No_DD_Radio";
};

_isolated_and_inside = TFAR_currentUnit call TFAR_fnc_vehicleIsIsolatedAndInside;
_depth = TFAR_currentUnit call TFAR_fnc_eyeDepth;
_can_speak = [_isolated_and_inside, _depth] call TFAR_fnc_canSpeak;

if ((call TFAR_fnc_haveSWRadio) and {[TFAR_currentUnit, _isolated_and_inside, _can_speak, _depth] call TFAR_fnc_canUseSWRadio}) then {
	_freq = [];	
	_radios = TFAR_currentUnit call TFAR_fnc_radiosList;
	{
		if !(_x call TFAR_fnc_getSwSpeakers) then {
			if (_routeCapable) then {
				_channel = _x call TFAR_fnc_getSwChannel;
				_additional = _x call TFAR_fnc_getAdditionalSwChannel;
				if (_additional == _channel) then {
					_entry = [_x, _channel, _x call TFAR_fnc_getSwVolume, _x call TFAR_fnc_getAdditionalSwStereo] call TFAR_fnc_serializeRadioReceiveRoute;
					if (_entry != "") then {_freq pushBack _entry};
				} else {
					_entry = [_x, _channel, _x call TFAR_fnc_getSwVolume, _x call TFAR_fnc_getSwStereo] call TFAR_fnc_serializeRadioReceiveRoute;
					if (_entry != "") then {_freq pushBack _entry};
					if (_additional > -1) then {
						_entry = [_x, _additional, _x call TFAR_fnc_getSwVolume, _x call TFAR_fnc_getAdditionalSwStereo] call TFAR_fnc_serializeRadioReceiveRoute;
						if (_entry != "") then {_freq pushBack _entry};
					};
				};
			} else {
				if (!_useV2) then {
					if ((_x call TFAR_fnc_getAdditionalSwChannel) == (_x call TFAR_fnc_getSwChannel)) then {
						_freq pushBack format ["%1%2|%3|%4", _x call TFAR_fnc_getSwFrequency, _x call TFAR_fnc_getSwRadioCode, _x call TFAR_fnc_getSwVolume, _x call TFAR_fnc_getAdditionalSwStereo];
					} else {
						_freq pushBack format ["%1%2|%3|%4", _x call TFAR_fnc_getSwFrequency, _x call TFAR_fnc_getSwRadioCode, _x call TFAR_fnc_getSwVolume, _x call TFAR_fnc_getSwStereo];
						if ((_x call TFAR_fnc_getAdditionalSwChannel) > -1) then {
							_freq pushBack format ["%1%2|%3|%4", [_x, (_x call TFAR_fnc_getAdditionalSwChannel) + 1] call TFAR_fnc_GetChannelFrequency, _x call TFAR_fnc_getSwRadioCode, _x call TFAR_fnc_getSwVolume, _x call TFAR_fnc_getAdditionalSwStereo];
						};
					};
				};
			};
		};		
		true;
	} count (_radios);
};
if ((call TFAR_fnc_haveLRRadio) and {[TFAR_currentUnit, _isolated_and_inside, _depth] call TFAR_fnc_canUseLRRadio}) then {
	_freq_lr = [];
	_radios = TFAR_currentUnit call TFAR_fnc_lrRadiosList;
	{
		if !(_x call TFAR_fnc_getLrSpeakers) then {
			if (_routeCapable) then {
				_channel = _x call TFAR_fnc_getLrChannel;
				_additional = _x call TFAR_fnc_getAdditionalLrChannel;
				if (_additional == _channel) then {
					_entry = [_x, _channel, _x call TFAR_fnc_getLrVolume, _x call TFAR_fnc_getAdditionalLrStereo] call TFAR_fnc_serializeRadioReceiveRoute;
					if (_entry != "") then {_freq_lr pushBack _entry};
				} else {
					_entry = [_x, _channel, _x call TFAR_fnc_getLrVolume, _x call TFAR_fnc_getLrStereo] call TFAR_fnc_serializeRadioReceiveRoute;
					if (_entry != "") then {_freq_lr pushBack _entry};
					if (_additional > -1) then {
						_entry = [_x, _additional, _x call TFAR_fnc_getLrVolume, _x call TFAR_fnc_getAdditionalLrStereo] call TFAR_fnc_serializeRadioReceiveRoute;
						if (_entry != "") then {_freq_lr pushBack _entry};
					};
				};
			} else {
				if (!_useV2) then {
					if ((_x call TFAR_fnc_getAdditionalLrChannel) == (_x call TFAR_fnc_getLrChannel)) then {
						_freq_lr pushBack format ["%1%2|%3|%4", _x call TFAR_fnc_getLrFrequency, _x call TFAR_fnc_getLrRadioCode, _x call TFAR_fnc_getLrVolume, _x call TFAR_fnc_getAdditionalLrStereo];
					} else {
						_freq_lr pushBack format ["%1%2|%3|%4", _x call TFAR_fnc_getLrFrequency, _x call TFAR_fnc_getLrRadioCode, _x call TFAR_fnc_getLrVolume, _x call TFAR_fnc_getLrStereo];
						if ((_x call TFAR_fnc_getAdditionalLrChannel) > -1) then {
							_freq_lr pushBack format ["%1%2|%3|%4", [_x, (_x call TFAR_fnc_getAdditionalLrChannel) + 1] call TFAR_fnc_GetChannelFrequency, _x call TFAR_fnc_getLrRadioCode, _x call TFAR_fnc_getLrVolume, _x call TFAR_fnc_getAdditionalLrStereo];
						};
					};
				};
			};
		};
		true;
	} count (_radios);
};
if ((call TFAR_fnc_haveDDRadio) and {[_depth, _isolated_and_inside] call TFAR_fnc_canUseDDRadio}) then {
	if (_routeCapable) then {
		_route = call TFAR_fnc_getDiverRadioRoute;
		_entry = _route call TFAR_fnc_serializeRadioRoute;
		if (_entry != "") then {_freq_dd = _entry};
	} else {
		if (!_useV2) then {_freq_dd = TF_dd_frequency};
	};
};
_alive = alive TFAR_currentUnit;
if (_alive) then {
	TFAR_player_name = name player;
};

_nickname = TFAR_player_name;
_globalVolume = TFAR_currentUnit getVariable "tf_globalVolume";
if (isNil "_globalVolume") then {
	_globalVolume = 1.0;
};
_voiceVolume = TFAR_currentUnit getVariable "tf_voiceVolume";
if (isNil "_voiceVolume") then {
	_voiceVolume = 1.0;
};
_spectator = TFAR_currentUnit getVariable "tf_forceSpectator";
if (isNil "_spectator") then {
	_spectator = false;
};
if (_spectator) then {
	_alive = false;
};
_receivingDistanceMultiplicator = TFAR_currentUnit getVariable "tf_receivingDistanceMultiplicator";
if (isNil "_receivingDistanceMultiplicator") then {
	_receivingDistanceMultiplicator = 1.0;
};

TFAR_pluginRouteModeActive = false;
if (_useV2 and {_routeCapable}) then {
	_request = format["FREQ	2	%1	%2	%3	%4	%5	%6	%7	%8	%9	%10	%11	%12	%13", if ((count _freq) == 0) then {"-"} else {_freq joinString ";"}, if ((count _freq_lr) == 0) then {"-"} else {_freq_lr joinString ";"}, _freq_dd, _alive, TF_speak_volume_meters min TF_max_voice_volume, TF_dd_volume_level, _nickname, waves, TF_terrain_interception_coefficient, _globalVolume, _voiceVolume, _receivingDistanceMultiplicator, TF_speakerDistance];
	_result = "task_force_radio_pipe" callExtension _request;
	TFAR_pluginRouteModeActive = _result == "OK";
	if (TFAR_pluginRouteModeActive) then {TFAR_pluginRouteWarningShown = false};
};

if (!_useV2) then {
	_request = format["FREQ	%1	%2	%3	%4	%5	%6	%7	%8	%9	%10	%11	%12	%13", str(_freq), str(_freq_lr), _freq_dd, _alive, TF_speak_volume_meters min TF_max_voice_volume, TF_dd_volume_level, _nickname, waves, TF_terrain_interception_coefficient, _globalVolume, _voiceVolume, _receivingDistanceMultiplicator, TF_speakerDistance];
	_result = "task_force_radio_pipe" callExtension _request;
} else {
	if !(TFAR_pluginRouteModeActive) then {
		// Old/missing plugins receive no usable v1 radio routes in a new mission.
		_request = format["FREQ	%1	%2	%3	%4	%5	%6	%7	%8	%9	%10	%11	%12	%13", str(["No_SW_Radio"]), str(["No_LR_Radio"]), "No_DD_Radio", _alive, TF_speak_volume_meters min TF_max_voice_volume, TF_dd_volume_level, _nickname, waves, TF_terrain_interception_coefficient, _globalVolume, _voiceVolume, _receivingDistanceMultiplicator, TF_speakerDistance];
		_result = "task_force_radio_pipe" callExtension _request;
	};
};
