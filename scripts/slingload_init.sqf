if (hasInterface) then {
    [] spawn {
        waitUntil {!isNull player};

        // Monitor for new vehicles and enable rope attach
        [] spawn {
            while {true} do {
                {
                    // Enable rope attach on all vehicles
                    if (_x isKindOf "AllVehicles" && !(_x isKindOf "Man") && !(_x isKindOf "Air")) then {
                        _x enableRopeAttach true;
                    };

                    if (_x isKindOf "Helicopter") then {
                        _x enableRopeAttach true;
                    };
                } forEach vehicles;
                sleep 15;
            };
        };

        player addAction [
            "<t color='#00FF00'>Hook Vehicle (Rope)</t>",
            {
                private _helicopter = vehicle player;
                private _nearVehicles = nearestObjects [_helicopter, ["AllVehicles"], 40];
                _nearVehicles = _nearVehicles - [_helicopter];
                _nearVehicles = _nearVehicles select {
                    alive _x && 
                    !(_x isKindOf "Man") && 
                    !(_x isKindOf "Air") &&
                    isNull (_x getVariable ["attachedToHeli", objNull])
                };

                if (count _nearVehicles > 0) then {
                    private _target = _nearVehicles select 0;

                    // Store original mass before modifying
                    private _originalMass = getMass _target;
                    _target setVariable ["originalMass", _originalMass, true];

                    // Dramatically reduce cargo weight for easy lifting
                    _target setMass (_originalMass * 0.2); // Make cargo 80% lighter

                    // Create rope
                    private _ropeLength = 20;
                    private _rope = ropeCreate [_helicopter, [0,0,-2], _target, [0,0,1], _ropeLength];

                    if (!isNull _rope) then {
                        _helicopter setVariable ["slingRope", _rope, true];
                        _helicopter setVariable ["attachedVehicle", _target, true];
                        _target setVariable ["attachedToHeli", _helicopter, true];

                        hint format ["Hooked %1 (Weight: %2kg -> %3kg)", 
                            getText (configFile >> "CfgVehicles" >> typeOf _target >> "displayName"),
                            _originalMass,
                            getMass _target
                        ];
                    } else {
                        // Restore original weight if rope creation failed
                        _target setMass _originalMass;
                        hint "Failed to create rope - check positioning";
                    };
                } else {
                    hint "No vehicles nearby to hook (within 40m)";
                };
            },
            nil,
            10,
            true,
            true,
            "",
            "vehicle player isKindOf 'Helicopter' && driver (vehicle player) == player && isNull ((vehicle player) getVariable ['slingRope', objNull])",
            10
        ];

        player addAction [
            "<t color='#FF0000'>Release Rope</t>",
            {
                private _helicopter = vehicle player;
                private _rope = _helicopter getVariable ["slingRope", objNull];
                private _attachedVehicle = _helicopter getVariable ["attachedVehicle", objNull];

                // Check altitude for parachute deployment
                private _altitude = (getPosASL _helicopter) select 2;
                private _groundAltitude = getTerrainHeightASL (getPos _helicopter);
                private _heightAboveGround = _altitude - _groundAltitude;

                ropeDestroy _rope;
                _helicopter setVariable ["slingRope", objNull, true];

                // Restore original weight of cargo vehicle
                if (!isNull _attachedVehicle) then {
                    private _originalMass = _attachedVehicle getVariable ["originalMass", getMass _attachedVehicle];
                    _attachedVehicle setMass _originalMass;
                    _attachedVehicle setVariable ["attachedToHeli", objNull, true];
                    _attachedVehicle setVariable ["originalMass", nil, true];
                    _helicopter setVariable ["attachedVehicle", objNull, true];

                    // Deploy parachute if above 100m with delay
                    if (_heightAboveGround > 100) then {
                        hint format ["AIRDROP: Released %1 from %2m altitude - Parachute deploying in 3 seconds!", 
                            getText (configFile >> "CfgVehicles" >> typeOf _attachedVehicle >> "displayName"),
                            round _heightAboveGround
                        ];

                        // Spawn delayed parachute deployment with velocity compensation
                        [_attachedVehicle] spawn {
                            params ["_vehicle"];

                            // 3 second delay
                            sleep 3;

                            // Check if vehicle still exists and is falling
                            if (!isNull _vehicle && alive _vehicle) then {
                                // Get current vehicle position and velocity
                                private _vehiclePos = getPosASL _vehicle;
                                private _vehicleVel = velocity _vehicle;

                                // Predict where vehicle will be in the next second (for better positioning)
                                private _predictedPos = [
                                    (_vehiclePos select 0) + ((_vehicleVel select 0) * 0.5),
                                    (_vehiclePos select 1) + ((_vehicleVel select 1) * 0.5),
                                    (_vehiclePos select 2) + 5  // Spawn parachute 5m above vehicle
                                ];

                                // Create parachute at predicted position
                                private _parachute = createVehicle ["B_Parachute_02_F", _predictedPos, [], 0, "FLY"];
                                _parachute setPosASL _predictedPos;

                                // Give parachute similar velocity to vehicle for better attachment
                                _parachute setVelocity [
                                    (_vehicleVel select 0) * 0.8,
                                    (_vehicleVel select 1) * 0.8,
                                    (_vehicleVel select 2) * 0.5
                                ];

                                // Wait a moment for physics to settle, then attach
                                sleep 0.5;

                                // Create rope attachment with longer rope for high-speed scenarios
                                private _ropeLength = 15;
                                private _parachuteRope = ropeCreate [_parachute, [0,0,-2], _vehicle, [0,0,1], _ropeLength];

                                // If rope creation failed, try again with vehicle's current position
                                if (isNull _parachuteRope) then {
                                    sleep 0.5;
                                    _parachute setPosASL [(getPosASL _vehicle) select 0, (getPosASL _vehicle) select 1, ((getPosASL _vehicle) select 2) + 8];
                                    sleep 0.5;
                                    _parachuteRope = ropeCreate [_parachute, [0,0,-2], _vehicle, [0,0,1], _ropeLength];
                                };

                                // If still failed, try shorter rope
                                if (isNull _parachuteRope) then {
                                    sleep 0.5;
                                    _parachute setPosASL [(getPosASL _vehicle) select 0, (getPosASL _vehicle) select 1, ((getPosASL _vehicle) select 2) + 3];
                                    sleep 0.5;
                                    _parachuteRope = ropeCreate [_parachute, [0,0,-2], _vehicle, [0,0,1], 8];
                                };

                                if (!isNull _parachuteRope) then {
                                    // Store parachute reference for cleanup
                                    _vehicle setVariable ["parachute", _parachute, true];
                                    _vehicle setVariable ["parachuteRope", _parachuteRope, true];

                                    // Visual/audio feedback for parachute deployment
                                    ["PARACHUTE DEPLOYED!"] remoteExec ["hint", 0];

                                    // Monitor for landing and cleanup
                                    [_vehicle, _parachute, _parachuteRope] spawn {
                                        params ["_vehicle", "_chute", "_chuteRope"];

                                        // Wait for actual landing with better detection
                                        waitUntil {
                                            sleep 0.5;

                                            private _vehiclePos = getPosASL _vehicle;
                                            private _groundHeight = getTerrainHeightASL (getPos _vehicle);
                                            private _heightAboveGround = (_vehiclePos select 2) - _groundHeight;
                                            private _velocity = velocity _vehicle;
                                            private _verticalSpeed = _velocity select 2;

                                            // Only cleanup when safely landed
                                            (_heightAboveGround < 3 && _verticalSpeed > -3 && alive _vehicle) ||
                                            !alive _vehicle ||
                                            !alive _chute ||
                                            isNull _chuteRope
                                        };

                                        // Give extra time before cleanup
                                        sleep 2;

                                        // Clean up parachute system
                                        if (!isNull _chuteRope) then { 
                                            ropeDestroy _chuteRope;
                                        };
                                        if (!isNull _chute) then { 
                                            sleep 2;
                                            deleteVehicle _chute;
                                        };

                                        if (!isNull _vehicle) then {
                                            _vehicle setVariable ["parachute", nil, true];
                                            _vehicle setVariable ["parachuteRope", nil, true];
                                            ["Vehicle landed safely!"] remoteExec ["systemChat", 0];
                                        };
                                    };
                                } else {
                                    // Parachute attachment failed completely
                                    ["PARACHUTE ATTACHMENT FAILED - EMERGENCY LANDING!"] remoteExec ["hint", 0];
                                    if (!isNull _parachute) then { deleteVehicle _parachute; };
                                };
                            };
                        };
                    } else {
                        hint format ["Released %1 (Weight restored to %2kg)", 
                            getText (configFile >> "CfgVehicles" >> typeOf _attachedVehicle >> "displayName"),
                            _originalMass
                        ];
                    };
                } else {
                    hint "Rope released";
                };
            },
            nil,
            10,
            true,
            true,
            "",
            "vehicle player isKindOf 'Helicopter' && driver (vehicle player) == player && !isNull ((vehicle player) getVariable ['slingRope', objNull])",
            10
        ];

        // // Cargo status with altitude info
        // player addAction [
        //     "<t color='#FFFF00'>Cargo Status</t>",
        //     {
        //         private _helicopter = vehicle player;
        //         private _rope = _helicopter getVariable ["slingRope", objNull];
        //         private _attachedVehicle = _helicopter getVariable ["attachedVehicle", objNull];
                
        //         // Calculate altitude info
        //         private _altitude = (getPosASL _helicopter) select 2;
        //         private _groundAltitude = getTerrainHeightASL (getPos _helicopter);
        //         private _heightAboveGround = _altitude - _groundAltitude;
                
        //         if (!isNull _attachedVehicle) then {
        //             private _currentMass = getMass _attachedVehicle;
        //             private _originalMass = _attachedVehicle getVariable ["originalMass", "Unknown"];
                    
        //             hint format [
        //                 "Attached: %1\nOriginal Weight: %2kg\nCurrent Weight: %3kg\nAltitude: %4m %5",
        //                 getText (configFile >> "CfgVehicles" >> typeOf _attachedVehicle >> "displayName"),
        //                 _originalMass,
        //                 _currentMass,
        //                 round _heightAboveGround,
        //                 if (_heightAboveGround > 100) then {"(PARACHUTE ZONE)"} else {"(NORMAL DROP)"}
        //             ];
        //         } else {
        //             hint format ["No vehicle attached\nAltitude: %1m", round _heightAboveGround];
        //         };
        //     },
        //     nil,
        //     1,
        //     true,
        //     true,
        //     "",
        //     "vehicle player isKindOf 'Helicopter'",
        //     10
        // ];
        // // Emergency weight reset action - only visible when NOT in helicopter
        // player addAction [
        //     "<t color='#FFAA00'>Reset Vehicle Weight</t>",
        //     {
        //         private _target = cursorTarget;
        //         if (!isNull _target && _target isKindOf "AllVehicles") then {
        //             private _originalMass = _target getVariable ["originalMass", nil];
        //             if (!isNil "_originalMass") then {
        //                 _target setMass _originalMass;
        //                 _target setVariable ["originalMass", nil, true];
        //                 hint format ["Reset weight of %1 to %2kg", typeOf _target, _originalMass];
        //             } else {
        //                 hint "Vehicle has no stored original weight";
        //             };
        //         } else {
        //             hint "Look at a vehicle";
        //         };
        //     },
        //     nil,
        //     1,
        //     false,
        //     true,
        //     "",
        //     "!(vehicle player isKindOf 'Helicopter') && !isNull cursorTarget && cursorTarget isKindOf 'AllVehicles'",
        //     10
        // ];

        // Cleanup system - restore weights if helicopter is destroyed
        [] spawn {
            while {true} do {
                {
                    private _attachedVehicle = _x getVariable ["attachedVehicle", objNull];
                    if (!isNull _attachedVehicle && !alive _x) then {
                        // Helicopter destroyed, restore cargo weight
                        private _originalMass = _attachedVehicle getVariable ["originalMass", nil];
                        if (!isNil "_originalMass") then {
                            _attachedVehicle setMass _originalMass;
                            _attachedVehicle setVariable ["originalMass", nil, true];
                            _attachedVehicle setVariable ["attachedToHeli", objNull, true];
                        };
                    };
                } forEach (vehicles select {_x isKindOf "Helicopter"});
                sleep 30;
            };
        };
    };
    
    systemChat "Parachute airdrop slingloading system loaded!";
};