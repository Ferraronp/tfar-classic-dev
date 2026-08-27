/*
 	Name: TFAR_fnc_radioToRequestCount
 	
 	Author(s):
		NKey
		L-H

 	Description:
		Searches through all the items assigned to and on the player and checks if it is a prototype radio
		and then creates an array of all the classnames of the prototype radios and returns it.
	
	Parameters:
		BOOLEAN - Replace all radios
		or ARRAY:
			0: BOOLEAN - Replace all radios
			1: OBJECT - Unit whose radios are checked
 	
 	Returns:
		ARRAY - List of all radio classes to be replaced.
 	
 	Example:
		_radios = false call TFAR_fnc_radioToRequestCount;
*/
private ["_to_remove", "_allRadios", "_personalRadio", "_riflemanRadio", "_defaultRadio", "_classes", "_unit", "_ownerId", "_playerRadios", "_duplicate", "_radioOwner"];

_allRadios = _this;
_unit = TFAR_currentUnit;
if (typename _this == "ARRAY") then {
	_allRadios = _this select 0;
	_unit = _this select 1;
};

waitUntil {sleep 0.1;!(isNull _unit)};

_to_remove = [];
// The legacy UID-only owner lets the player's body and a Zeus-controlled unit
// keep the same instanced classname. Scope the owner to the concrete remote
// unit so the normal replacement path gives it independent settings.
_ownerId = _unit call TFAR_fnc_getRadioOwnerId;
_playerRadios = [];
if (_unit != player) then {
	_playerRadios = player call TFAR_fnc_radiosList;
};

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
	_duplicate = (_unit != player) and {_x in _playerRadios};
    if (_x call TFAR_fnc_isPrototypeRadio) then {
		_to_remove pushBack _x;
        TF_first_radio_request = true;
    } else {
		if (_x call TFAR_fnc_isRadio) then {
			_radioOwner = _x call TFAR_fnc_getRadioOwner;
			if ((_radioOwner == "") and {!_duplicate}) then {
				[_x, _ownerId] call TFAR_fnc_setRadioOwner;
				_radioOwner = _ownerId;
			};
			if ((_radioOwner != _ownerId) or {_allRadios} or {_duplicate}) then {
				_to_remove pushBack _x;
				TF_settingsToCopy set [0, _x];
				TF_first_radio_request = true;
			};
		};
	};	
	true;
} count (assignedItems _unit);
{
	_duplicate = (_unit != player) and {_x in _playerRadios};
    if (_x call TFAR_fnc_isPrototypeRadio) then {
        _to_remove pushBack _x;
    } else {		
		if (_x call TFAR_fnc_isRadio) then {
			_radioOwner = _x call TFAR_fnc_getRadioOwner;
			if ((_radioOwner == "") and {!_duplicate}) then {
				[_x, _ownerId] call TFAR_fnc_setRadioOwner;
				_radioOwner = _ownerId;
			};
			if ((_radioOwner != _ownerId) or {_allRadios} or {_duplicate}) then {
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