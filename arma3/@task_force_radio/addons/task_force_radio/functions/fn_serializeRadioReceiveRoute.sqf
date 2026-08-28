/* Parameters: [radio, zeroBasedChannel, volume, stereo]. */
private ["_radio", "_channel", "_volume", "_stereo", "_route", "_serialized"];
_radio = _this select 0;
_channel = _this select 1;
_volume = _this select 2;
_stereo = _this select 3;
_route = [_radio, _channel] call TFAR_fnc_getRadioRoute;
_serialized = _route call TFAR_fnc_serializeRadioRoute;
if (_serialized == "") exitWith {""};

format ["%1,%2,%3", _serialized, _volume, _stereo]
