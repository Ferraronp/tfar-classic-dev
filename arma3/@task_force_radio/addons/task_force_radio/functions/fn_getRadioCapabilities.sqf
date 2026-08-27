/*
	Name: TFAR_fnc_getRadioCapabilities

	Description:
		Returns the waveform and frequency grid supported by a SW or LR radio.
		Custom radios may define tf_waveform, tf_frequencyMin,
		tf_frequencyMax and tf_frequencyStepKhz.

	Parameters:
		STRING - SW classname, or ARRAY [OBJECT, qualifier] - LR radio.

	Returns:
		ARRAY [waveform, minKhz, maxKhz, stepKhz].
*/
private ["_radio", "_isLr", "_waveform", "_minimum", "_maximum", "_stepKhz", "_value", "_config", "_minimumKhz", "_maximumKhz"];
_radio = _this;
_isLr = typeName _radio == "ARRAY";

if (!_isLr and {typeName _radio != "STRING"}) exitWith {[]};
if (_isLr and {(count _radio) < 2}) exitWith {[]};

_waveform = TFAR_DEFAULT_VOICE_WAVEFORM;
_stepKhz = TFAR_DEFAULT_FREQUENCY_STEP_KHZ;

if (_isLr) then {
	_minimum = TF_MIN_ASIP_FREQ;
	_maximum = TF_MAX_ASIP_FREQ;

	_value = [_radio select 0, "tf_waveform"] call TFAR_fnc_getLrRadioProperty;
	if ((typeName _value == "STRING") and {_value != ""}) then {
		_waveform = _value;
	};
	_value = [_radio select 0, "tf_frequencyMin"] call TFAR_fnc_getLrRadioProperty;
	if (typeName _value == "SCALAR") then {_minimum = _value};
	_value = [_radio select 0, "tf_frequencyMax"] call TFAR_fnc_getLrRadioProperty;
	if (typeName _value == "SCALAR") then {_maximum = _value};
	_value = [_radio select 0, "tf_frequencyStepKhz"] call TFAR_fnc_getLrRadioProperty;
	if (typeName _value == "SCALAR") then {_stepKhz = _value};
} else {
	_minimum = TF_MIN_SW_FREQ;
	_maximum = TF_MAX_SW_FREQ;
	_config = configFile >> "CfgWeapons" >> _radio;

	if (isText (_config >> "tf_waveform")) then {
		_value = getText (_config >> "tf_waveform");
		if (_value != "") then {_waveform = _value};
	};
	if (isNumber (_config >> "tf_frequencyMin")) then {
		_minimum = getNumber (_config >> "tf_frequencyMin");
	};
	if (isNumber (_config >> "tf_frequencyMax")) then {
		_maximum = getNumber (_config >> "tf_frequencyMax");
	};
	if (isNumber (_config >> "tf_frequencyStepKhz")) then {
		_stepKhz = getNumber (_config >> "tf_frequencyStepKhz");
	};
};

_minimumKhz = _minimum call TFAR_fnc_normalizeFrequencyKhz;
_maximumKhz = _maximum call TFAR_fnc_normalizeFrequencyKhz;
[_waveform, _minimumKhz, _maximumKhz, round _stepKhz]
