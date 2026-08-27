/*
	Name: TFAR_fnc_isValidProtectionCode

	Description:
		Checks the canonical three-digit NET code format while preserving leading zeros.
*/
private ["_code", "_characters", "_invalid"];
_code = _this;

if (typeName _code != "STRING") exitWith {false};
_characters = toArray _code;
if ((count _characters) != 3) exitWith {false};

_invalid = false;
{
	if ((_x < 48) or {_x > 57}) exitWith {
		_invalid = true;
	};
} forEach _characters;

!_invalid
