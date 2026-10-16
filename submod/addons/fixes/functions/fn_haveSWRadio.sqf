/* TFAR Classic Fixes: derived from TFAR 0.9.12 and the Zeus fixes in
 * Ferraronp/tfar-classic-dev (ca67f8e). Original authors: Michail Nikolaev
 * (NKey), L-H and TFAR contributors. Changes: TFAR Classic contributors.
 * Distributed under APL-SA; see the mod's LICENSE.md and AUTHORS.md.
 */
/*
    Name: TFAR_fnc_haveSWRadio

    Author(s):

    Description:
        Returns whether the player has a SW radio

    Parameters:
    Nothing

    Returns:
    BOOLEAN

    Example:
    _hasSW = call TFAR_fnc_haveSWRadio;
 */
private ["_result"];
_result = false;
if (isNil {TFAR_currentUnit} || {isNull (TFAR_currentUnit)}) exitWith{false};
if !(missionNamespace getVariable ["TFAR_currentUnitRadioReady", true]) exitWith {false};
{
    if (_x call TFAR_fnc_isRadio) exitWith {_result = true};
    true;
} count (assignedItems TFAR_currentUnit);
_result
