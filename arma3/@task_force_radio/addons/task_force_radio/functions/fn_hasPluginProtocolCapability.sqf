/* Returns whether the local TeamSpeak plugin negotiated a protocol capability. */
private ["_capability"];
_capability = _this;
if (typeName _capability != "STRING") exitWith {false};
if !(call TFAR_fnc_negotiatePluginProtocol) exitWith {false};

(TFAR_pluginProtocolVersion == 2) and {_capability in TFAR_pluginProtocolCapabilities}
