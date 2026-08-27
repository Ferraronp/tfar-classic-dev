/*
	Name: TFAR_fnc_cloneRadioSettings

	Description:
		Copies a radio settings array including all mutable nested arrays.

	Parameters:
		ARRAY - Radio settings.

	Returns:
		ARRAY - Independent settings snapshot.
*/
private ["_settings", "_copy", "_nested"];
_settings = _this;

if (typeName _settings != "ARRAY") exitWith {[]};

_copy = +_settings;
{
	if ((count _copy) > _x) then {
		if (!isNil {_copy select _x}) then {
			_nested = _copy select _x;
			if (typeName _nested == "ARRAY") then {
				_copy set [_x, +_nested];
			};
		};
	};
} forEach [TF_FREQ_OFFSET, TF_PROTECTION_CODES_OFFSET, TF_TALK_GROUPS_OFFSET];

_copy
