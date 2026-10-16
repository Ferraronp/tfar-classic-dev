/* TFAR Classic Fixes bootstrap. APL-SA; see LICENSE.md.
 * The original TFAR ClientInit runs unchanged. Wait until it has initialized
 * the state used by onCurrentUnitChanged before installing the unit watcher.
 */
if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["TFARCF_initializing", false]) exitWith {};
TFARCF_initializing = true;

[] spawn {
    waitUntil {
        sleep 0.05;
        !(isNull player)
            and {!(isNil "TFAR_currentUnit")}
            and {!(isNil "TF_radio_request_mutex")}
            and {!(isNil "TF_respawnedAt")}
            and {!(isNil "TF_first_radio_request")}
    };

    if (isNil "TFAR_currentUnitRadioReady") then {
        TFAR_currentUnitRadioReady = true;
    };

    // Register once per mission. Polling also covers old CBA/remote-control
    // combinations that do not consistently emit the CBA unit event.
    ["unit", {
        [call TFAR_fnc_currentUnit] call TFAR_fnc_onCurrentUnitChanged;
    }, true] call CBA_fnc_addPlayerEventHandler;

    TFARCF_unitWatcher = [{
        private "_unit";
        _unit = call TFAR_fnc_currentUnit;
        if (_unit != TFAR_currentUnit) then {
            [_unit, TFAR_currentUnit] call TFAR_fnc_onCurrentUnitChanged;
        };
    }, 0.05] call CBA_fnc_addPerFrameHandler;

    [call TFAR_fnc_currentUnit] call TFAR_fnc_onCurrentUnitChanged;
    TFARCF_initialized = true;
    diag_log "TFAR Classic Fixes 1.0.0 initialized (original TFAR Classic 0.9.12 required)";
};
