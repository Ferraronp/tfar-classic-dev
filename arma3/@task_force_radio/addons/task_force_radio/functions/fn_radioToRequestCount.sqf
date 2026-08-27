/*
 	Name: TFAR_fnc_radioToRequestCount
 	
 	Author(s):
		NKey
		L-H

 	Description:
		Searches through all the items assigned to and on the player and checks if it is a prototype radio
		and then creates an array of all the classnames of the prototype radios and returns it.
	
	Parameters:
		BOOLEAN - Regardless of whether the radio is prototype or not, return it as a radio to be replaced.
 	
 	Returns:
		ARRAY - List of all radio classes to be replaced.
 	
 	Example:
		_radios = false call TFAR_fnc_radioToRequestCount;
*/
private ["_to_remove", "_allRadios", "_personalRadio", "_riflemanRadio", "_defaultRadio", "_classes", "_unit", "_ownerId"];

_allRadios = _this;
_unit = TFAR_currentUnit;
if (typename _this == "ARRAY") then {
	_allRadios = _this select 0;
	_unit = _this select 1;
};

waitUntil {sleep 0.1;!(isNull _unit)};

_to_remove = [];
// The legacy UID-only owner lets the player\'s body and a Zeus-controlled unit
// keep the same instanced classname. Scope the owner to the concrete remote
// unit so the normal replacement path gives it independent settings.
_ownerId = _unit call TFAR_fnc_getRadioOwnerId;

_personalRadio = nil;
_riflemanRadio = nil;

_classes = call TFAR_fnc_getDefaultRadioClasses;
_personalRadio = _classes select 1;
_riflemanRadio = _classes select 2;

if ((TF_give_personal_radio_to_regular_soldier) or {leader _unit == _unit} or {rankId _unit >= 2}) then {
	_defaultRadio = _personalRadio;
} else {
	_defaultRadio = _riflemanRadio;
};

TF_settingsToCopy = [];
{
    if (_x call TFAR_fnc_isPrototypeRadio) then {
		_to_remove pushBack _x;
        TF_first_radio_request = true;
    } else {
		if (_x call TFAR_fnc_isRadio) then {
			if ((_x call TFAR_fnc_getRadioOwner) == "") then {
				[_x, _ownerId] call TFAR_fnc_setRadioOwner;
			};
			if (((_x call TFAR_fnc_getRadioOwner) != _ownerId) or _allRadios) then {
				_to_remove pushBack _x;
				TF_settingsToCopy set [0, _x];
				TF_first_radio_request = true;
			};
		};
	};	
	true;
} count (assignedItems _unit);
{
    if (_x call TFAR_fnc_isPrototypeRadio) then {
        _to_remove pushBack _x;
    } else {		
		if (_x call TFAR_fnc_isRadio) then {
			if ((_x call TFAR_fnc_getRadioOwner) == "") then {
				[_x, _ownerId] call TFAR_fnc_setRadioOwner;
			};
			if (((_x call TFAR_fnc_getRadioOwner) != _ownerId) or _allRadios) then {
				_to_remove pushBack _x;
				TF_settingsToCopy pushBack _x;
			};
		};
	};
	true;
} count (items _unit);

{
	_unit unassignItem _x;
	_unit removeItem _x;
	if (_x == "ItemRadio") then {
		_to_remove set [_forEachIndex, _defaultRadio];
	};
} forEach _to_remove;
_to_remove