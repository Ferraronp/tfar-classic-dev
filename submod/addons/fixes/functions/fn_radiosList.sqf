/* TFAR Classic Fixes: derived from TFAR 0.9.12 and the Zeus fixes in
 * Ferraronp/tfar-classic-dev (ca67f8e). Original authors: Michail Nikolaev
 * (NKey), L-H and TFAR contributors. Changes: TFAR Classic contributors.
 * Distributed under APL-SA; see the mod's LICENSE.md and AUTHORS.md.
 */
/*
    Name: TFAR_fnc_radiosList

    Author(s):
        NKey

    Description:
        List of all the player's SW radios.

    Parameters:
        0: OBJECT: unit

    Returns:
        ARRAY - List of all the player's SW radios.

    Example:
        _radios = TFAR_currentUnit call TFAR_fnc_radiosList;
*/
if (!(isNil "TFAR_currentUnit") and {_this == TFAR_currentUnit} and {!(missionNamespace getVariable ["TFAR_currentUnitRadioReady", true])}) exitWith {[]};

private ["_result"];
_result = [];
{
    if (_x call TFAR_fnc_isRadio) then {
        _result pushBack _x;
    };
    true;
} count (assignedItems _this);

{
    if (_x call TFAR_fnc_isRadio) then {
        _result pushBack _x;
    };
    true;
} count (items _this);
_result
