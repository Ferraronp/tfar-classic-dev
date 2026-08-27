/*
 	Name: TFAR_fnc_setSwSettings
 	
 	Author(s):
		NKey
 	
 	Description:
		Saves the settings for the passed radio and broadcasts it to all clients and the server.
 	
 	Parameters: 
		0: STRING - Radio classname
		1: ARRAY - Settings, usually acquired via TFAR_fnc_getSwSettings and then changed.
		2: BOOLEAN - Set local only 
 	
 	Returns:
		Nothing
 	
 	Example:
		_settings = (call TFAR_fnc_activeSwRadio) call TFAR_fnc_getSwSettings;
		_settings set [0, 2]; // sets the active channel to 2
		[(call TFAR_fnc_activeSwRadio), _settings] call TFAR_fnc_setSwSettings;
*/
private ["_radio_id", "_value", "_variableName", "_local", "_storedValue", "_localValue"];
_radio_id = _this select 0;
_value = (_this select 1) call TFAR_fnc_migrateRadioSettings;
_variableName = format["%1_settings", _radio_id];
_local = false;
if (count _this == 3) then {
	_local = _this select 2;
};
_storedValue = _value call TFAR_fnc_cloneRadioSettings;
_localValue = _value call TFAR_fnc_cloneRadioSettings;
missionNamespace setVariable [_variableName, _storedValue];
missionNamespace setVariable [_variableName + "_local", _localValue];
if !(_local) then {		
	publicVariable _variableName;
}
