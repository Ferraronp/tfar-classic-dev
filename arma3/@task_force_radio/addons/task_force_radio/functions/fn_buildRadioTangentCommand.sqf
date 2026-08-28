/*
	Builds a Legacy or negotiated v2 tangent command.
	Parameters: [command, action, radio, zeroBasedChannel, legacyFrequency, range, subtype].
*/
private ["_command", "_action", "_radio", "_channel", "_legacyFrequency", "_range", "_subtype", "_mode", "_tab", "_code", "_route", "_cacheName", "_cached", "_cachedRelease", "_serialized"];
_command = _this select 0;
_action = _this select 1;
_radio = _this select 2;
_channel = _this select 3;
_legacyFrequency = _this select 4;
_range = _this select 5;
_subtype = _this select 6;
_tab = toString [9];

_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {_mode = "Legacy"};
_mode = toUpper _mode;
if !(_mode in ["OPEN", "KEYED"]) exitWith {
	if (_command == "TANGENT_DD") then {
		format ["%1%2%3%2%4%2%5%2%6", _command, _tab, _action, _legacyFrequency, 0, _subtype]
	} else {
		if (typeName _radio == "ARRAY") then {
			_code = _radio call TFAR_fnc_getLrRadioCode;
		} else {
			_code = _radio call TFAR_fnc_getSwRadioCode;
		};
		format ["%1%2%3%2%4%5%2%6%2%7", _command, _tab, _action, _legacyFrequency, _code, _range, _subtype]
	}
};

_cacheName = switch (_command) do {
	case "TANGENT_LR": {"TFAR_lrTangentV2Cache"};
	case "TANGENT_DD": {"TFAR_ddTangentV2Cache"};
	default {"TFAR_swTangentV2Cache"};
};
_cached = missionNamespace getVariable [_cacheName, []];
_cachedRelease = (_action == "RELEASED") and {typeName _cached == "ARRAY"} and {(count _cached) == 3};

if (!_cachedRelease and {!(missionNamespace getVariable ["TFAR_pluginRouteModeActive", false])}) then {
	call TFAR_fnc_sendFrequencyInfo;
};
if (!_cachedRelease and {
	!(missionNamespace getVariable ["TFAR_pluginRouteModeActive", false])
	or {!("radio_route_v2" call TFAR_fnc_hasPluginProtocolCapability)}
}) exitWith {
	if !(missionNamespace getVariable ["TFAR_pluginRouteWarningShown", false]) then {
		TFAR_pluginRouteWarningShown = true;
		[parseText (localize "STR_radio_routing_plugin_incompatible"), 8] call TFAR_fnc_showHint;
		diag_log "TFAR: protocol-v2 radio routing is unavailable; radio transmission was blocked";
	};
	""
};

if (_action == "RELEASED") then {
	if (_cachedRelease) then {
		_route = _cached select 0;
		_range = _cached select 1;
		_subtype = _cached select 2;
	} else {
		if (_command == "TANGENT_DD") then {
			_route = call TFAR_fnc_getDiverRadioRoute;
		} else {
			_route = [_radio, _channel] call TFAR_fnc_getRadioRoute;
		};
	};
	missionNamespace setVariable [_cacheName, []];
} else {
	if (_command == "TANGENT_DD") then {
		_route = call TFAR_fnc_getDiverRadioRoute;
	} else {
		_route = [_radio, _channel] call TFAR_fnc_getRadioRoute;
	};
	missionNamespace setVariable [_cacheName, [_route, _range, _subtype]];
};

_serialized = _route call TFAR_fnc_serializeRadioRoute;
if (_serialized == "") exitWith {""};
format ["%1%2%3%2%4%2%5%2%6%2%7%2%8%2%9%2%10", _command, _tab, 2, _action, _route select 0, _route select 1, _route select 2, _route select 3, _range, _subtype]
