/* TFAR Classic Fixes: derived from TFAR 0.9.12 and the Zeus fixes in
 * Ferraronp/tfar-classic-dev (ca67f8e). Original authors: Michail Nikolaev
 * (NKey), L-H and TFAR contributors. Changes: TFAR Classic contributors.
 * Distributed under APL-SA; see the mod's LICENSE.md and AUTHORS.md.
 */
/*
    Name: TFAR_fnc_currentUnit

    Author(s):
    Nkey

    Description:
    Return current player unit (player or remote controlled by Zeus).

    Parameters:
    Nothing

    Returns:
    OBJECT: current unit

    Example:
    call TFAR_fnc_currentUnit;
*/
private ["_unit"];
_unit = missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", objNull];

if ((isNull _unit) or {!alive _unit}) then {
    player
} else {
    _unit
}
