/*
	Name: TFAR_fnc_migrateRadioSettings

	Description:
		Upgrades legacy SW/LR settings to schema v2 without moving Classic fields.
		Missing protection codes use the explicit mission map, then the Classic
		side-code map. Unknown non-empty legacy codes remain invalid so a v2
		route cannot silently fall back to an open network.

	Parameters:
		ARRAY - Radio settings.

	Returns:
		ARRAY - Independent schema-v2 settings.
*/
private ["_settings", "_migrated", "_frequencies", "_channelCount", "_codes", "_talkGroups", "_schemaVersion", "_mode", "_legacyCode", "_defaultCode", "_customMap", "_mapped", "_entry", "_builtInMap"];
_settings = _this;

if (typeName _settings != "ARRAY") exitWith {[]};

_migrated = _settings call TFAR_fnc_cloneRadioSettings;
_schemaVersion = 0;
if ((count _migrated) > TF_SETTINGS_SCHEMA_OFFSET) then {
	if (!isNil {_migrated select TF_SETTINGS_SCHEMA_OFFSET}) then {
		_schemaVersion = _migrated select TF_SETTINGS_SCHEMA_OFFSET;
	};
};

// Preserve future schemas instead of truncating fields this version does not know.
if ((typeName _schemaVersion == "SCALAR") and {_schemaVersion > TF_SETTINGS_SCHEMA_VERSION}) exitWith {
	_migrated
};

_frequencies = [];
if ((count _migrated) > TF_FREQ_OFFSET) then {
	if (typeName (_migrated select TF_FREQ_OFFSET) == "ARRAY") then {
		_frequencies = _migrated select TF_FREQ_OFFSET;
	};
};
_channelCount = count _frequencies;

_mode = missionNamespace getVariable ["TFAR_radioNetworkMode", "Legacy"];
if (typeName _mode != "STRING") then {
	_mode = "Legacy";
};
_mode = toUpper _mode;
_defaultCode = TFAR_DEFAULT_PROTECTION_CODE;

if (_mode != "OPEN") then {
	_legacyCode = "";
	if ((count _migrated) > TF_CODE_OFFSET) then {
		if (!isNil {_migrated select TF_CODE_OFFSET}) then {
			if (typeName (_migrated select TF_CODE_OFFSET) == "STRING") then {
				_legacyCode = _migrated select TF_CODE_OFFSET;
			};
		};
	};

	// A mission-supplied mapping takes precedence over the built-in defaults.
	_defaultCode = "";
	_mapped = false;
	_customMap = missionNamespace getVariable ["TFAR_legacyProtectionCodeMap", []];
	if (typeName _customMap != "ARRAY") then {
		_customMap = [];
	};
	{
		_entry = _x;
		if (!_mapped and {typeName _entry == "ARRAY"}) then {
			if ((count _entry) >= 2) then {
				if (!isNil {_entry select 0}) then {
					if ((typeName (_entry select 0) == "STRING") and {(_entry select 0) == _legacyCode}) then {
						_mapped = true;
						if (!isNil {_entry select 1}) then {
							if ((_entry select 1) call TFAR_fnc_isValidProtectionCode) then {
								_defaultCode = _entry select 1;
							};
						};
					};
				};
			};
		};
	} forEach _customMap;

	if (!_mapped) then {
		_builtInMap = [
			["_bluefor", "100"],
			["_opfor", "200"],
			["_independent", "300"],
			["", "000"]
		];
		{
			if (!_mapped and {(_x select 0) == _legacyCode}) then {
				_defaultCode = _x select 1;
				_mapped = true;
			};
		} forEach _builtInMap;
	};
};

_codes = [];
if ((count _migrated) > TF_PROTECTION_CODES_OFFSET) then {
	if (!isNil {_migrated select TF_PROTECTION_CODES_OFFSET}) then {
		if (typeName (_migrated select TF_PROTECTION_CODES_OFFSET) == "ARRAY") then {
			_codes = +(_migrated select TF_PROTECTION_CODES_OFFSET);
		};
	};
};
if (_mode == "OPEN") then {
	_codes = [];
};
while {(count _codes) < _channelCount} do {
	_codes pushBack _defaultCode;
};
if ((count _codes) > _channelCount) then {
	_codes resize _channelCount;
};

// Talk groups are protocol-reserved in this slice and remain zero for every slot.
_talkGroups = [];
while {(count _talkGroups) < _channelCount} do {
	_talkGroups pushBack TFAR_DEFAULT_TALK_GROUP;
};

_migrated set [TF_PROTECTION_CODES_OFFSET, _codes];
_migrated set [TF_TALK_GROUPS_OFFSET, _talkGroups];
_migrated set [TF_SETTINGS_SCHEMA_OFFSET, TF_SETTINGS_SCHEMA_VERSION];
_migrated
