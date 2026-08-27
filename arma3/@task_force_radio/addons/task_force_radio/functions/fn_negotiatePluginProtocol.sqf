/*
	Name: TFAR_fnc_negotiatePluginProtocol

	Description:
		Negotiates the local Arma-to-TeamSpeak protocol and optional capabilities.
		A missing or old plugin leaves the addon in legacy protocol mode.

	Returns:
		BOOLEAN - Whether protocol v2 was negotiated.
*/
private ["_tab", "_request", "_result", "_parts", "_capabilityString", "_capabilities", "_knownCapabilities"];

if (isNil "TFAR_pluginProtocolNextNegotiation") then {
	TFAR_pluginProtocolNegotiated = false;
	TFAR_pluginProtocolVersion = 1;
	TFAR_pluginProtocolCapabilities = [];
	TFAR_pluginProtocolNextNegotiation = 0;
};

if (diag_tickTime < TFAR_pluginProtocolNextNegotiation) exitWith {
	TFAR_pluginProtocolNegotiated
};
TFAR_pluginProtocolNextNegotiation = diag_tickTime + 5;

// Reset first so a reconnect or malformed response cannot retain stale v2 state.
TFAR_pluginProtocolNegotiated = false;
TFAR_pluginProtocolVersion = 1;
TFAR_pluginProtocolCapabilities = [];

_tab = toString [9];
_knownCapabilities = ["radio_route_v2", "speakers_v2"];
_request = format ["PROTOCOL%1%2%1%3", _tab, 2, _knownCapabilities joinString ","];
_result = "task_force_radio_pipe" callExtension _request;
_parts = _result splitString _tab;

if ((count _parts) != 3) exitWith {false};
if ((_parts select 0) != "PROTOCOL_OK") exitWith {false};
if ((_parts select 1) != "2") exitWith {false};

_capabilityString = _parts select 2;
_capabilities = [];
if (_capabilityString != "-") then {
	_capabilities = _capabilityString splitString ",";
};

if ({!(_x in _knownCapabilities)} count _capabilities > 0) exitWith {false};
if ((count _capabilities) != (count (_capabilities arrayIntersect _capabilities))) exitWith {false};

TFAR_pluginProtocolNegotiated = true;
TFAR_pluginProtocolVersion = 2;
TFAR_pluginProtocolCapabilities = _capabilities;
true
