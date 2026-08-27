/*
	Name: TFAR_fnc_getRadioOwnerId

	Author(s):
		TFAR Classic contributors

	Description:
		Returns the ownership key used for an instanced SW radio. The player's
		own unit keeps the legacy Steam UID key. A Zeus remote-controlled unit
		gets a key scoped to that concrete unit so two units controlled by the
		same player cannot share one radio instance and its settings.

	Parameters:
		OBJECT - Unit which owns the radio

	Returns:
		STRING - Radio ownership key

	Example:
		_ownerId = TFAR_currentUnit call TFAR_fnc_getRadioOwnerId;
*/
private ["_unit", "_uid", "_networkId"];

_unit = _this;
_uid = getPlayerUID player;

if ((isNull _unit) or {_unit == player}) exitWith {
	_uid
};

_networkId = netId _unit;
if ((_networkId == "") or {_networkId == "0:0"}) then {
	_networkId = str _unit;
};

format ["%1:%2", _uid, _networkId]
