/* TFAR Classic Fixes: derived from TFAR 0.9.12 and the Zeus fixes in
 * Ferraronp/tfar-classic-dev (ca67f8e). Original authors: Michail Nikolaev
 * (NKey), L-H and TFAR contributors. Changes: TFAR Classic contributors.
 * Distributed under APL-SA; see the mod's LICENSE.md and AUTHORS.md.
 */
/*
    Name: TFAR_fnc_activeSwRadio

    Author(s):
        NKey

    Description:
        Returns the active SW radio.

    Parameters:
        Nothing

    Returns:
        STRING: Active SW radio

    Example:
        _radio = call TFAR_fnc_activeSwRadio;
*/
if !(missionNamespace getVariable ["TFAR_currentUnitRadioReady", true]) exitWith {nil};

private ["_result"];
_result = nil;
{
    if (_x call TFAR_fnc_isRadio) exitWith {_result = _x};
    true;
} count (assignedItems TFAR_currentUnit);
_result
