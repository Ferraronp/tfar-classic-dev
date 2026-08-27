/*
	Name: TFAR_fnc_normalizeFrequencyKhz

	Description:
		Converts a frequency in MHz to its canonical integer-kHz representation.

	Parameters:
		STRING or SCALAR - Frequency in MHz.

	Returns:
		SCALAR - Frequency in kHz, or -1 for malformed input.
*/
private ["_value", "_mhz", "_characters", "_invalid", "_decimalPoints", "_digits"];
_value = _this;

if (typeName _value == "SCALAR") exitWith {
	round (_value * 1000)
};
if (typeName _value != "STRING") exitWith {-1};

_characters = toArray _value;
if ((count _characters) == 0) exitWith {-1};

_invalid = false;
_decimalPoints = 0;
_digits = 0;
{
	if ((_x >= 48) and {_x <= 57}) then {
		_digits = _digits + 1;
	} else {
		if (_x == 46) then {
			_decimalPoints = _decimalPoints + 1;
			if (_decimalPoints > 1) exitWith {_invalid = true};
		} else {
			_invalid = true;
		};
	};
} forEach _characters;

if (_invalid or {_digits == 0}) exitWith {-1};
_mhz = parseNumber _value;
round (_mhz * 1000)
