// Wait for everything to be ready
waitUntil {!isNull player && alive player};
waitUntil {time > 5};

// Execute Zeus creation on server
[] remoteExec ["giveAllPlayersZeus", 2];

systemChat "Zeus request sent to server...";