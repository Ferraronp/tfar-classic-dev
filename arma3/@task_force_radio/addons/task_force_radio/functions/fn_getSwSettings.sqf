/*
 	Name: TFAR_fnc_getSwSettings
 	
 	Author(s):
		NKey
		L-H
 	
 	Description:
		Returns the current settings for the passed radio.
 	
 	Parameters: 
 	0: String - Radio classname
 	
 	Returns:
	ARRAY - settings.
 	
 	Example:
	(call TFAR_fnc_activeSwRadio) call TFAR_fnc_getSwSettings;
*/
#include "script.h"
private ["_variableName", "_value", "_rc", "_schemaVersion", "_needsMigration", "_frequencyCount", "_codes", "_talkGroups", "_migrated"];
_variableName = format["%1_settings", _this];
_value = missionNamespace getVariable _variableName;
if (isNil "_value") then {
	if (!(TF_use_saved_sw_setting) or (isNil "TF_saved_active_sw_settings")) then {
		private ["_parent", "_defaultRadios"];
		_defaultRadios = call TFAR_fnc_getDefaultRadioClasses;
		_parent = getText (ConfigFile >> "CfgWeapons" >> _this >> "tf_parent");
		if ((_defaultRadios select 1) == _parent or {(_defaultRadios select 2) == _parent}) then {
			_value = (group TFAR_currentUnit) getVariable "tf_sw_frequency";
		};
		if (isNil "_value") then {
			_value = call TFAR_fnc_generateSwSettings;
		};			
	} else {
		_value = TF_saved_active_sw_settings;
	};
	if (TF_use_saved_sw_setting) then {
		TF_use_saved_sw_setting = false;
	};
	_rc = _value select TF_CODE_OFFSET;
	if (isNil "_rc") then {
		private ["_parent", "_code", "_hasDefaultEncryption"];
		_code = getText (ConfigFile >>  "CfgWeapons" >> _this >> "tf_encryptionCode");
		_hasDefaultEncryption = (_code == "tf_west_radio_code") or {_code == "tf_east_radio_code"} or {_code == "tf_guer_radio_code"};
		if (_hasDefaultEncryption and {(TFAR_currentUnit call BIS_fnc_objectSide) != civilian}) then {
			_parent = getText (ConfigFile >> "CfgWeapons" >> _this >> "tf_parent");
			private "_default";
			_default = call TFAR_fnc_getDefaultRadioClasses;
			if ((_default select 1) == _parent or {(_default select 2) == _parent}) then {
				_rc = missionNamespace getVariable format ["tf_%1_radio_code", (TFAR_currentUnit call BIS_fnc_objectSide)];
			}else{
				_rc = missionNamespace getVariable [_code, ""];
			};
		} else {
			_rc = "";
			if (_code != "") then {
				_rc = missionNamespace getVariable [_code, ""];
			};
		};
		_value set [TF_CODE_OFFSET, _rc];		
	};
	_value = _value call TFAR_fnc_migrateRadioSettings;
	[_this, _value, true] call TFAR_fnc_setSwSettings;
};

_schemaVersion = 0;
if ((count _value) > TF_SETTINGS_SCHEMA_OFFSET) then {
	if (!isNil {_value select TF_SETTINGS_SCHEMA_OFFSET}) then {
		if (typeName (_value select TF_SETTINGS_SCHEMA_OFFSET) == "SCALAR") then {
			_schemaVersion = _value select TF_SETTINGS_SCHEMA_OFFSET;
		};
	};
};
_needsMigration = _schemaVersion < TF_SETTINGS_SCHEMA_VERSION;
if (_schemaVersion == TF_SETTINGS_SCHEMA_VERSION) then {
	_frequencyCount = 0;
	if ((count _value) > TF_FREQ_OFFSET) then {
		if (typeName (_value select TF_FREQ_OFFSET) == "ARRAY") then {
			_frequencyCount = count (_value select TF_FREQ_OFFSET);
		};
	};
	_codes = [];
	if ((count _value) > TF_PROTECTION_CODES_OFFSET) then {
		if (!isNil {_value select TF_PROTECTION_CODES_OFFSET}) then {
			_codes = _value select TF_PROTECTION_CODES_OFFSET;
		};
	};
	_talkGroups = [];
	if ((count _value) > TF_TALK_GROUPS_OFFSET) then {
		if (!isNil {_value select TF_TALK_GROUPS_OFFSET}) then {
			_talkGroups = _value select TF_TALK_GROUPS_OFFSET;
		};
	};
	_needsMigration = (typeName _codes != "ARRAY")
		or {typeName _talkGroups != "ARRAY"}
		or {(count _codes) != _frequencyCount}
		or {(count _talkGroups) != _frequencyCount};
};

_migrated = _value call TFAR_fnc_migrateRadioSettings;
if (_needsMigration) then {
	[_this, _migrated, true] call TFAR_fnc_setSwSettings;
};
_migrated
