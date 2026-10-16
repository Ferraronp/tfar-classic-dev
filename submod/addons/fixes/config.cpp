class CfgPatches
{
    class tfar_classic_fixes
    {
        name = "TFAR Classic Fixes";
        author = "Ferraronp; TFAR Classic contributors";
        url = "https://github.com/Ferraronp/tfar-classic-dev";
        requiredVersion = 1.60;
        requiredAddons[] = {"task_force_radio", "cba_main", "cba_events", "cba_common"};
        units[] = {};
        weapons[] = {};
        version = 1.0;
        versionStr = "1.0.0";
        versionAr[] = {1, 0, 0};
    };
};

// Merge into the original function category before the Functions Library
// compiles it. Do not change its category-wide file path: all unlisted TFAR
// functions must continue to load from the original task_force_radio PBO.
class CfgFunctions
{
    class TFAR
    {
        class Radio
        {
            class activeSwRadio {file = "\tfar_classic_fixes\functions\fn_activeSwRadio.sqf";};
            class currentUnit {file = "\tfar_classic_fixes\functions\fn_currentUnit.sqf";};
            class getRadioOwnerId {file = "\tfar_classic_fixes\functions\fn_getRadioOwnerId.sqf";};
            class haveSWRadio {file = "\tfar_classic_fixes\functions\fn_haveSWRadio.sqf";};
            class onCurrentUnitChanged {file = "\tfar_classic_fixes\functions\fn_onCurrentUnitChanged.sqf";};
            class onSwDialogOpen {file = "\tfar_classic_fixes\functions\fn_onSwDialogOpen.sqf";};
            class processPlayerPositions {file = "\tfar_classic_fixes\functions\fn_processPlayerPositions.sqf";};
            class processRespawn {file = "\tfar_classic_fixes\functions\fn_processRespawn.sqf";};
            class radioReplaceProcess {file = "\tfar_classic_fixes\functions\fn_radioReplaceProcess.sqf";};
            class radioToRequestCount {file = "\tfar_classic_fixes\functions\fn_radioToRequestCount.sqf";};
            class radiosList {file = "\tfar_classic_fixes\functions\fn_radiosList.sqf";};
            class requestRadios {file = "\tfar_classic_fixes\functions\fn_requestRadios.sqf";};
            class sendFrequencyInfo {file = "\tfar_classic_fixes\functions\fn_sendFrequencyInfo.sqf";};
        };
    };
    class TFARCF
    {
        tag = "TFARCF";
        class Lifecycle
        {
            file = "\tfar_classic_fixes\functions";
            class init {postInit = 1;};
        };
    };
};
