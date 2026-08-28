/* Serializes [waveform, frequencyKhz, protectionCode, talkGroup] for protocol v2. */
if ((typeName _this != "ARRAY") or {(count _this) != 4}) exitWith {""};
if ((typeName (_this select 0) != "STRING")
	or {typeName (_this select 1) != "SCALAR"}
	or {typeName (_this select 2) != "STRING"}
	or {typeName (_this select 3) != "SCALAR"}) exitWith {""};

format ["%1,%2,%3,%4", _this select 0, _this select 1, _this select 2, _this select 3]
