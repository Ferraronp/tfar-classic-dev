/* Returns Legacy frequency keys or structured v2 routes for one SW/LR radio. */
private ["_radio", "_isLr", "_mode", "_channel", "_additional", "_frequency", "_code", "_routes", "_route", "_serialized"];
_radio = _this;
_isLr = typeName _radio == "ARRAY";
_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {_mode = "Legacy"};
_mode = toUpper _mode;

if (_isLr) then {
	_channel = _radio call TFAR_fnc_getLrChannel;
	_additional = _radio call TFAR_fnc_getAdditionalLrChannel;
} else {
	_channel = _radio call TFAR_fnc_getSwChannel;
	_additional = _radio call TFAR_fnc_getAdditionalSwChannel;
};

if !(_mode in ["OPEN", "KEYED"]) exitWith {
	if (_isLr) then {
		_frequency = _radio call TFAR_fnc_getLrFrequency;
		_code = _radio call TFAR_fnc_getLrRadioCode;
	} else {
		_frequency = _radio call TFAR_fnc_getSwFrequency;
		_code = _radio call TFAR_fnc_getSwRadioCode;
	};
	_routes = format ["%1%2", _frequency, _code];
	if (_additional > -1) then {
		_routes = _routes + format ["|%1%2", [_radio, _additional + 1] call TFAR_fnc_GetChannelFrequency, _code];
	};
	_routes
};

if !(missionNamespace getVariable ["TFAR_pluginRouteModeActive", false]) exitWith {""};
if !("radio_route_v2" call TFAR_fnc_hasPluginProtocolCapability) exitWith {""};
if !("speakers_v2" call TFAR_fnc_hasPluginProtocolCapability) exitWith {""};

_routes = [];
_route = [_radio, _channel] call TFAR_fnc_getRadioRoute;
_serialized = _route call TFAR_fnc_serializeRadioRoute;
if (_serialized != "") then {_routes pushBack _serialized};
if ((_additional > -1) and {_additional != _channel}) then {
	_route = [_radio, _additional] call TFAR_fnc_getRadioRoute;
	_serialized = _route call TFAR_fnc_serializeRadioRoute;
	if (_serialized != "") then {_routes pushBack _serialized};
};
if ((count _routes) == 0) exitWith {""};
_routes joinString "|"
