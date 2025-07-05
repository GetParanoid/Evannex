// Run evannex gamemode
execVM "core\evannexInit.sqf";
// Enable friendly markers
execVM "core\client\QS_icons.sqf";

execVM "scripts\slingload_init.sqf";

// Server-side Zeus assignment for all players
if (isServer) then {
    giveAllPlayersZeus = {
        {
            private _player = _x;
            if (isNull (getAssignedCuratorLogic _player)) then {
                // Create Zeus module
                private _zeus = createGroup sideLogic createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];

                // Configure Zeus
                _zeus setCuratorCoef ["Place", 0];
                _zeus setCuratorCoef ["Delete", 0];
                _zeus setCuratorCoef ["Synchronize", 0];

                // Assign to player
                _player assignCurator _zeus;

                // Add all objects
                _zeus addCuratorEditableObjects [allUnits + vehicles + allMissionObjects "All", true];

                // Notify player
                ["Zeus access granted! Press Y to open."] remoteExec ["systemChat", _player];

                // Keep adding new objects
                [_zeus] spawn {
                    params ["_curator"];
                    while {!isNull _curator} do {
                        sleep 15;
                        _curator addCuratorEditableObjects [allUnits + vehicles + allMissionObjects "All", true];
                    };
                };
            };
        } forEach allPlayers;
    };

    // Also run this for JIP players
    addMissionEventHandler ["PlayerConnected", {
        params ["_id", "_uid", "_name", "_jip", "_owner"];
        if (_jip) then {
            [{count allPlayers > _this}, count allPlayers, {[] call giveAllPlayersZeus;}] call BIS_fnc_waitUntilAndExecute;
        };
    }];
};