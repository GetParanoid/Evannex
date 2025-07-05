private _object = _this select 0;
	{
		[_x, _object] remoteExec ["br_fn_addToZeus"];
		//_x addCuratorEditableObjects [[_object],true];
	} forEach allCurators;

br_fn_addToZeus = {
	params["_zeus", "_object"];
	_zeus addCuratorEditableObjects [[_object], true];
};