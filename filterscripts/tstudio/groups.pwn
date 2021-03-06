#include <YSI\y_hooks>

// Group objects
new Text3D:GroupObjectText[MAX_PLAYERS][MAX_TEXTURE_OBJECTS];
new bool:GroupedObjects[MAX_PLAYERS][MAX_TEXTURE_OBJECTS];
new Float:PivotOffset[MAX_PLAYERS][XYZ];
new Float:LastPivot[MAX_PLAYERS][XYZR];
new Float:LastGroupPosition[MAX_PLAYERS][XYZ];
new bool:PivotReset[MAX_PLAYERS];

hook OnFilterScriptInit()
{
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
		for(new j = 0; j < MAX_TEXTURE_OBJECTS; j++)
		{
	        GroupObjectText[i][j] = Text3D:-1;
	    }
	}
	return 1;
}


hook OnPlayerDisconnect(playerid, reason)
{
	for(new i = 0; i < MAX_TEXTURE_OBJECTS; i++)
	{
		if(_:GroupObjectText[playerid][i])
		{
			DestroyDynamic3DTextLabel(GroupObjectText[playerid][i]);
	        GroupObjectText[playerid][i] = Text3D:-1;
		}
    }
	ClearGroup(playerid);
	return 1;
}

HideGroupLabels(playerid)
{
	for(new i = 0; i < MAX_TEXTURE_OBJECTS; i++)
	{
		if(_:GroupObjectText[playerid][i])
		{
            UpdateDynamic3DTextLabelText(GroupObjectText[playerid][i], 0, "");
		}
    }
}

ShowGroupLabels(playerid)
{
	for(new i = 0; i < MAX_TEXTURE_OBJECTS; i++)
	{
		if(_:GroupObjectText[playerid][i])
		{
            UpdateDynamic3DTextLabelText(GroupObjectText[playerid][i], 0x7D26CDFF, "Grouped");
		}
    }
}




public OnUpdateGroup3DText(index)
{
	foreach(new i : Player)
	{
		if(_:GroupObjectText[i][index] != -1)
		{
			DestroyDynamic3DTextLabel(GroupObjectText[i][index]);
			GroupObjectText[i][index] = Text3D:-1;
		}
		
        if(GroupedObjects[i][index])
        {
			// 3D Text Label (To identify objects)
			new line[32];
			format(line, sizeof(line), "Grouped");

			// Shows the models index
		    GroupObjectText[i][index] = CreateDynamic3DTextLabel(line, 0x7D26CDFF, ObjectData[index][oX], ObjectData[index][oY], ObjectData[index][oZ]+0.5, TEXT3D_DRAW_DIST, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0,  -1, -1, i);

			Streamer_Update(i);
        }
	}
	return 1;
}

public OnDeleteGroup3DText(index)
{
	foreach(new i : Player)
	{
        if(GroupedObjects[i][index])
        {
			DestroyDynamic3DTextLabel(GroupObjectText[i][index]);
			GroupObjectText[i][index] = Text3D:-1;
		}
	}
	return 1;
}


hook OnPlayerSelectDynamicObject(playerid, objectid, modelid, Float:x, Float:y, Float:z)
{
	if(GetEditMode(playerid) == EDIT_MODE_GROUP)
	{
	    new Keys,ud,lr,index;
	    GetPlayerKeys(playerid,Keys,ud,lr);

		// Find edit object
		foreach(new i : Objects)
		{
			// Object found
		    if(ObjectData[i][oID] == objectid)
			{
				index = i;
			    break;
			}
		}

		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		// Try and add to group
		if(Keys & KEY_CTRL_BACK || (InFlyMode(playerid) && (Keys & KEY_SECONDARY_ATTACK)))
		{
			if(GroupedObjects[playerid][index]) SendClientMessage(playerid, STEALTH_YELLOW, "Object is already in your group selection");
			else
			{
				SendClientMessage(playerid, STEALTH_GREEN, "Object added to your group selection");
				GroupedObjects[playerid][index] = true;
				OnUpdateGroup3DText(index);

			}
		}
		
		// Try and remove from group
		else if(Keys & KEY_WALK)
		{
			if(!GroupedObjects[playerid][index]) SendClientMessage(playerid, STEALTH_YELLOW, "Object is not in your group selection");
			else
			{
				SendClientMessage(playerid, STEALTH_GREEN, "Object removed from your group selection");
				GroupedObjects[playerid][index] = false;
				OnUpdateGroup3DText(index);
			}
		}
		else
		{
		    SendClientMessage(playerid, STEALTH_YELLOW, "Hold the 'H' key and click a object to select it");
		    SendClientMessage(playerid, STEALTH_YELLOW, "Hold the 'Walk' key and click a object to deselect it");

		}
	}
	return 1;
}

OnPlayerKeyStateGroupChange(playerid, newkeys, oldkeys)
{
	#pragma unused newkeys
    if(GetEditMode(playerid) == EDIT_MODE_OBJECTGROUP)
    {
		if(oldkeys & KEY_WALK)
		{
			if(PivotReset[playerid] == false) return 1;
			SendClientMessage(playerid, STEALTH_GREEN, "Pivot has been set");
			PivotReset[playerid] = false;
			return 1;
		}
    }
    return 0;
}

OnPlayerEditDOGroup(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	#pragma unused objectid
	if(response == EDIT_RESPONSE_FINAL)
	{
		// Get the center (never changes)
		new Float:gCenterX, Float:gCenterY, Float:gCenterZ;
		GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ);

		new time = GetTickCount();

		foreach(new i : Objects)
		{
	   		if(GroupedObjects[playerid][i])
			{
				SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
				
				new Float:offx, Float:offy, Float:offz;
				offx = (ObjectData[i][oX] + (x - gCenterX)) - PivotOffset[playerid][xPos];
				offy = (ObjectData[i][oY] + (y - gCenterY)) - PivotOffset[playerid][yPos];
				offz = (ObjectData[i][oZ] + (z - gCenterZ)) - PivotOffset[playerid][zPos];

                AttachObjectToPoint_GroupEdit(i, offx, offy, offz, x, y, z, rx, ry, rz, ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);
				SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);
  				SetDynamicObjectRot(ObjectData[i][oID], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);

			    sqlite_UpdateObjectPos(i);

			    UpdateObject3DText(i);
			}
		}

		EditingMode[playerid] = false;
		SetEditMode(playerid, EDIT_MODE_NONE);
				
		DestroyDynamicObject(PivotObject[playerid]);
	}
	else if(response == EDIT_RESPONSE_UPDATE)
	{

		// Get the center (never changes)
		new Float:gCenterX, Float:gCenterY, Float:gCenterZ;
		GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ);

	    new Keys,ud,lr;
	    GetPlayerKeys(playerid,Keys,ud,lr);

		if(Keys & KEY_WALK)
		{
			if(!PivotReset[playerid])
			{
		       	SetDynamicObjectPos(PivotObject[playerid], LastGroupPosition[playerid][xPos], LastGroupPosition[playerid][yPos], LastGroupPosition[playerid][zPos]);
				SendClientMessage(playerid, STEALTH_YELLOW, "Save your object before changing the pivot again");
			}
			else
			{
				PivotOffset[playerid][xPos] = x - LastPivot[playerid][xPos];
				PivotOffset[playerid][yPos] = y - LastPivot[playerid][yPos];
				PivotOffset[playerid][zPos] = z - LastPivot[playerid][zPos];

				SetDynamicObjectRot(PivotObject[playerid], 0.0, 0.0, 0.0);
			}
		}

		else
		{
			foreach(new i : Objects)
			{
		   		if(GroupedObjects[playerid][i])
				{
					new Float:offx, Float:offy, Float:offz, Float:newx, Float:newy, Float:newz, Float:newrx, Float:newry, Float:newrz;
					offx = (ObjectData[i][oX] + (x - gCenterX)) - PivotOffset[playerid][xPos];
					offy = (ObjectData[i][oY] + (y - gCenterY)) - PivotOffset[playerid][yPos];
					offz = (ObjectData[i][oZ] + (z - gCenterZ)) - PivotOffset[playerid][zPos];

                    AttachObjectToPoint_GroupEdit(i, offx, offy, offz, x, y, z, rx, ry, rz, newx, newy, newz, newrx, newry, newrz);
					SetDynamicObjectPos(ObjectData[i][oID], newx, newy, newz);
	  				SetDynamicObjectRot(ObjectData[i][oID], newrx, newry, newrz);
				}
			}

			LastGroupPosition[playerid][xPos] = x - PivotOffset[playerid][xPos];
			LastGroupPosition[playerid][yPos] = y - PivotOffset[playerid][yPos];
			LastGroupPosition[playerid][zPos] = z - PivotOffset[playerid][zPos];
			
			LastPivot[playerid][xPos] = x;
			LastPivot[playerid][yPos] = y;
			LastPivot[playerid][zPos] = z;

			LastPivot[playerid][xPos] = rx;
			LastPivot[playerid][yPos] = ry;
			LastPivot[playerid][zPos] = rz;

			
			PivotReset[playerid] = false;
		}
	}

	else if(response == EDIT_RESPONSE_CANCEL)
	{
		foreach(new i : Objects)
		{
	   		if(GroupedObjects[playerid][i])
			{
				SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);
  				SetDynamicObjectRot(ObjectData[i][oID], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);

				EditingMode[playerid] = false;
				SetEditMode(playerid, EDIT_MODE_NONE);
				DestroyDynamicObject(PivotObject[playerid]);
			}
		}
	}
	return 1;
}

stock ClearGroup(playerid)
{
	for(new i = 0; i < MAX_TEXTURE_OBJECTS; i++)
	{
		GroupedObjects[playerid][i] = false;
		OnUpdateGroup3DText(i);
	}
	return 1;
}

stock GroupUpdate(index)
{
	foreach(new i : Player)
	{
        GroupedObjects[i][index] = false;
	}
	return 1;
}

stock GroupRotate(playerid, Float:rx, Float:ry, Float:rz, update = true)
{
	new Float:gCenterX, Float:gCenterY, Float:gCenterZ;
	GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ);

	// Loop through all objects and perform rotation calculations
	foreach(new i : Objects)
	{
		if(GroupedObjects[playerid][i])
		{
			AttachObjectToPoint(i, gCenterX, gCenterY, gCenterZ, rx, ry, rz, ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);
			if(update)
			{
				SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);
				SetDynamicObjectRot(ObjectData[i][oID], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);
				UpdateObject3DText(i);
				sqlite_UpdateObjectPos(i);
			}
		}
	}
}

stock GetGroupCenter(playerid, &Float:X, &Float:Y, &Float:Z)
{
	new Float:highX = -9999999.0;
	new Float:highY = -9999999.0;
	new Float:highZ = -9999999.0;

	new Float:lowX  = 9999999.0;
	new Float:lowY  = 9999999.0;
	new Float:lowZ  = 9999999.0;

	new count;

	foreach(new i : Objects)
	{
		if(GroupedObjects[playerid][i])
		{
			if(ObjectData[i][oX] > highX) highX = ObjectData[i][oX];
			if(ObjectData[i][oY] > highY) highY = ObjectData[i][oY];
			if(ObjectData[i][oZ] > highZ) highZ = ObjectData[i][oZ];
			if(ObjectData[i][oX] < lowX) lowX = ObjectData[i][oX];
			if(ObjectData[i][oY] < lowY) lowY = ObjectData[i][oY];
			if(ObjectData[i][oZ] < lowZ) lowZ = ObjectData[i][oZ];
			count++;
		}
	}

	// Not enough objects grouped
	if(count < 1) return 0;


	X = (highX + lowX) / 2;
	Y = (highY + lowY) / 2;
	Z = (highZ + lowZ) / 2;

	return 1;
}

CMD:setgroup(playerid, arg[]) // in GUI
{
    MapOpenCheck();
    NoEditingMode(playerid);
    
    new groupid = strval(arg);
    
    new time = GetTickCount();

	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	if(PlayerHasGroup(playerid))
	{
		foreach(new i : Objects)
		{
			if(GroupedObjects[playerid][i])
			{
				SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
				ObjectData[i][oGroup] = groupid;
				OnUpdateGroup3DText(i);
				UpdateObject3DText(i);
				sqlite_ObjGroup(i);
			}
		}
		new line[128];
		format(line, sizeof(line), "Set all objects in your group to group: %i", groupid);
		SendClientMessage(playerid, STEALTH_GREEN, line);
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "You have no objects to set to group!");

	return 1;
}

CMD:selectgroup(playerid, arg[]) // in GUI
{
    MapOpenCheck();
    NoEditingMode(playerid);

    SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	new groupid = strval(arg);

	if(PlayerHasGroup(playerid)) ClearGroup(playerid);

	new count;
	foreach(new i : Objects)
	{
	    if(ObjectData[i][oGroup] == groupid)
		{
		    GroupedObjects[playerid][i] = true;
			OnUpdateGroup3DText(i);
			UpdateObject3DText(i);
		    count++;
		}
	}
	if(count)
	{
		new line[128];

		// Update the Group GUI
		UpdatePlayerGSelText(playerid);
		format(line, sizeof(line), "Selected group %i Objects: %i", groupid, count);
		SendClientMessage(playerid, STEALTH_GREEN, line);
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "There are no objects with this group id");
	return 1;
}


static PlayerHasGroup(playerid)
{
	foreach(new i : Objects)
	{
		if(GroupedObjects[playerid][i])
		{
			return 1;
		}
	}
	return 0;
}


// Edit a group
CMD:editgroup(playerid, arg[]) // in GUI
{
    MapOpenCheck();
    NoEditingMode(playerid);

	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	if(PlayerHasGroup(playerid))
	{
		GetGroupCenter(playerid, LastPivot[playerid][xPos], LastPivot[playerid][yPos], LastPivot[playerid][zPos]);
		
		LastGroupPosition[playerid][xPos] = LastPivot[playerid][xPos];
		LastGroupPosition[playerid][yPos] = LastPivot[playerid][yPos];
		LastGroupPosition[playerid][zPos] = LastPivot[playerid][zPos];
		
		PivotOffset[playerid][xPos] = 0.0;
		PivotOffset[playerid][yPos] = 0.0;
		PivotOffset[playerid][zPos] = 0.0;
		
		PivotObject[playerid] = CreateDynamicObject(1974, LastPivot[playerid][xPos], LastPivot[playerid][yPos], LastPivot[playerid][zPos], 0.0, 0.0, 0.0, -1, -1, playerid);

		Streamer_SetFloatData(STREAMER_TYPE_OBJECT, PivotObject[playerid], E_STREAMER_DRAW_DISTANCE, 300.0);

		SetDynamicObjectMaterial(PivotObject[playerid], 0, 10765, "airportgnd_sfse", "white", -256);

		Streamer_Update(playerid);

		EditingMode[playerid] = true;
		PivotReset[playerid] = true;
		SetEditMode(playerid, EDIT_MODE_OBJECTGROUP);
	    EditDynamicObject(playerid, PivotObject[playerid]);
	    
	    SendClientMessage(playerid, STEALTH_GREEN, "Editing your group");
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "You must have at least one object grouped");
	
	return 1;
}


CMD:gsel(playerid, arg[]) // In GUI
{
    NoEditingMode(playerid);

    MapOpenCheck();

	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	if(Iter_Count(Objects))
	{
		SetEditMode(playerid, EDIT_MODE_GROUP);
		SelectObject(playerid);
		SendClientMessage(playerid, STEALTH_GREEN, "Entered Group Selection Mode");
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "There are no objects right now");

	return 1;
}

CMD:gadd(playerid, arg[]) // In GUI
{
    MapOpenCheck();
	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
	if(isnull(arg)) return SendClientMessage(playerid, STEALTH_YELLOW, "You must supply an object index to group");
	new index = strval(arg);
	if(index < 0) return SendClientMessage(playerid, STEALTH_YELLOW, "Index can not be less than 0");
	if(index >= MAX_TEXTURE_OBJECTS)
	{
		new line[128];
		format(line, sizeof(line), "Index can not be greater than %i", MAX_TEXTURE_OBJECTS - 1);
		return SendClientMessage(playerid, STEALTH_YELLOW, line);
	}
	if(Iter_Contains(Objects, index))
	{
	    if(GroupedObjects[playerid][index]) SendClientMessage(playerid, STEALTH_YELLOW, "Object is already in your group selection");
	    else
	    {
			// Update the Group GUI
			UpdatePlayerGSelText(playerid);

			SendClientMessage(playerid, STEALTH_GREEN, "Object added to your group selection");
			GroupedObjects[playerid][index] = true;
			OnUpdateGroup3DText(index);
	    }
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "No object exists on that index");

	return 1;
}

CMD:grem(playerid, arg[]) // In GUI
{
    MapOpenCheck();
	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
	if(isnull(arg)) return SendClientMessage(playerid, STEALTH_YELLOW, "You must supply an object index to group");
	new index = strval(arg);
	if(index < 0) return SendClientMessage(playerid, STEALTH_YELLOW, "Index can not be less than 0");
	if(index >= MAX_TEXTURE_OBJECTS)
	{
		new line[128];
		format(line, sizeof(line), "Index can not be greater than %i", MAX_TEXTURE_OBJECTS - 1);
		return SendClientMessage(playerid, STEALTH_YELLOW, line);
	}
	if(Iter_Contains(Objects, index))
	{
		if(!GroupedObjects[playerid][index]) SendClientMessage(playerid, STEALTH_YELLOW, "Object is not in your group selection");
		else
		{
			// Update the Group GUI
			UpdatePlayerGSelText(playerid);

			SendClientMessage(playerid, STEALTH_GREEN, "Object removed from your group selection");
			GroupedObjects[playerid][index] = false;
			OnUpdateGroup3DText(index);
		}
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "No object exists on that index");

	return 1;
}

CMD:gclear(playerid, arg[]) // in  GUI
{
	MapOpenCheck();
    ClearGroup(playerid);
	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
    SendClientMessage(playerid, STEALTH_GREEN, "Your group selection has been cleared");

	// Update the Group GUI
	UpdatePlayerGSelText(playerid);

	return 1;
}

new bool:tmpgrp[MAX_TEXTURE_OBJECTS];

CMD:gclone(playerid, arg[]) // in  GUI
{
    MapOpenCheck();

	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	new index;
	new count;
	new time = GetTickCount();

	for(new i = 0; i < MAX_TEXTURE_OBJECTS; i++) { tmpgrp[i] = false; }
	
    foreach(new i : Objects)
    {
        if(GroupedObjects[playerid][i])
        {
			index = CloneObject(i, time);
            GroupedObjects[playerid][i] = false;
            tmpgrp[index] = true;
			OnUpdateGroup3DText(i);
			count++;
        }
    }
    
    // Update grouped objects
    for(new i = 0; i < MAX_TEXTURE_OBJECTS; i++)
	{
		GroupedObjects[playerid][i] = tmpgrp[i];
		if(GroupedObjects[playerid][i] == true)
		OnUpdateGroup3DText(i);
	}
    
    if(count)
	{
		// Update the Group GUI
		UpdatePlayerGSelText(playerid);

		new line[128];
		format(line, sizeof(line), "Cloned group selection Objects: %i", count);
		SendClientMessage(playerid, STEALTH_GREEN, line);
	}
    else SendClientMessage(playerid, STEALTH_YELLOW, "No group objects to clone");
    
    return 1;
}

CMD:gdelete(playerid, arg[]) // in  GUI
{
    MapOpenCheck();

	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	new count;
	new time = GetTickCount();

    foreach(new i : Objects)
    {
        if(GroupedObjects[playerid][i])
        {
			SaveUndoInfo(i, UNDO_TYPE_DELETED, time);
			i = DeleteDynamicObject(i);
        	count++;
        }
    }
    
    if(count)
	{
		// Update the Group GUI
		UpdatePlayerGSelText(playerid);

		new line[128];
		format(line, sizeof(line), "Deleted group selection Objects: %i", count);
		SendClientMessage(playerid, STEALTH_GREEN, line);
	}
    else SendClientMessage(playerid, STEALTH_YELLOW, "No group objects to delete");

	return 1;
}

CMD:gall(playerid, arg[]) // in  GUI
{
    MapOpenCheck();

	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	new count;

    foreach(new i : Objects)
	{
        GroupedObjects[playerid][i] = true;
		OnUpdateGroup3DText(i);
		count++;
    }

    if(count)
	{
		// Update the Group GUI
		UpdatePlayerGSelText(playerid);

		new line[128];
		format(line, sizeof(line), "Grouped All Objects", count);
		SendClientMessage(playerid, STEALTH_GREEN, line);
	}
    else SendClientMessage(playerid, STEALTH_YELLOW, "There are no objects to group");

	return 1;
}

// Move all grouped objects on X axis
CMD:gox(playerid, arg[])
{
    MapOpenCheck();

	new Float:dist;
	new time = GetTickCount();

	dist = floatstr(arg);
	if(dist == 0) dist = 1.0;

 	foreach(new i : Objects)
	{
		if(GroupedObjects[playerid][i])
		{
			SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
			
		    ObjectData[i][oX] += dist;

		    SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);

			UpdateObject3DText(i);

		    sqlite_UpdateObjectPos(i);
		}
	}
	// Update the Group GUI
	UpdatePlayerGSelText(playerid);

	return 1;
}

// Move all grouped objects on Y axis
CMD:goy(playerid, arg[])
{
    MapOpenCheck();

	new Float:dist;
    new time = GetTickCount();

	dist = floatstr(arg);
	if(dist == 0) dist = 1.0;

 	foreach(new i : Objects)
	{
		if(GroupedObjects[playerid][i])
		{
			SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
			
		    ObjectData[i][oY] += dist;

		    SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);

			UpdateObject3DText(i);

		    sqlite_UpdateObjectPos(i);

		}
	}

	// Update the Group GUI
	UpdatePlayerGSelText(playerid);


	return 1;
}

// Move all grouped objects on Z axis
CMD:goz(playerid, arg[])
{
    MapOpenCheck();

	new Float:dist;
	new time = GetTickCount();

	dist = floatstr(arg);
	if(dist == 0) dist = 1.0;

 	foreach(new i : Objects)
	{
		if(GroupedObjects[playerid][i])
		{
			SaveUndoInfo(i, UNDO_TYPE_EDIT, time);

		    ObjectData[i][oZ] += dist;

		    SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);

			UpdateObject3DText(i);

		    sqlite_UpdateObjectPos(i);
		}
	}

	// Update the Group GUI
	UpdatePlayerGSelText(playerid);

	return 1;
}

// Rotate map on RX
CMD:grx(playerid, arg[])
{
    MapOpenCheck();
	new time = GetTickCount();
	new Float:Delta;
	if(sscanf(arg, "f", Delta))
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "Usage: /grx <rotation> ");
		return 1;
	}

	// We need to get the map center as the rotation node
	new bool:value, Float:gCenterX, Float:gCenterY, Float:gCenterZ;
	
	if(PivotPointOn[playerid])
	{
		new bool:hasgroup;
		foreach(new i : Objects)
		{
		    if(GroupedObjects[playerid][i])
		    {
			    gCenterX = PivotPoint[playerid][xPos];
			    gCenterY = PivotPoint[playerid][yPos];
			    gCenterZ = PivotPoint[playerid][zPos];
				value = true;
                hasgroup = true;
				break;
			}
		}
		if(!hasgroup)
		{
			SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
			SendClientMessage(playerid, STEALTH_YELLOW, "There is not enough objects for this command to work");
		}
	}
	else if(GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ)) value = true;

	if(value)
	{
		// Loop through all objects and perform rotation calculations
		foreach(new i : Objects)
		{
			if(GroupedObjects[playerid][i])
			{
				SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
				AttachObjectToPoint(i, gCenterX, gCenterY, gCenterZ, Delta, 0.0, 0.0, ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);
				SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);
				SetDynamicObjectRot(ObjectData[i][oID], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);

				UpdateObject3DText(i);

				sqlite_UpdateObjectPos(i);

			}
		}

		// Update the Group GUI
		UpdatePlayerGSelText(playerid);

		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_GREEN, "Group RX rotation complete ");
	}
	else
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "There is not enough objects for this command to work");
	}

	return 1;
}

// Rotate map on RX
CMD:gry(playerid, arg[])
{
    MapOpenCheck();
	new time = GetTickCount();
	new Float:Delta;
	if(sscanf(arg, "f", Delta))
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "Usage: /gry <rotation> ");
		return 1;
	}

	// We need to get the map center as the rotation node
	new bool:value, Float:gCenterX, Float:gCenterY, Float:gCenterZ;

	if(PivotPointOn[playerid])
	{
		new bool:hasgroup;
		foreach(new i : Objects)
		{
		    if(GroupedObjects[playerid][i])
		    {
			    gCenterX = PivotPoint[playerid][xPos];
			    gCenterY = PivotPoint[playerid][yPos];
			    gCenterZ = PivotPoint[playerid][zPos];
				value = true;
                hasgroup = true;
				break;
			}
		}
		if(!hasgroup)
		{
			SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
			SendClientMessage(playerid, STEALTH_YELLOW, "There is not enough objects for this command to work");
		}
	}
	else if(GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ)) value = true;

	if(value)
	{
		// Loop through all objects and perform rotation calculations
		foreach(new i : Objects)
		{
			if(GroupedObjects[playerid][i])
			{
				SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
				AttachObjectToPoint(i, gCenterX, gCenterY, gCenterZ, 0.0, Delta, 0.0, ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);
				SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);
				SetDynamicObjectRot(ObjectData[i][oID], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);

				UpdateObject3DText(i);

				sqlite_UpdateObjectPos(i);
			}
		}

   		// Update the Group GUI
		UpdatePlayerGSelText(playerid);

		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_GREEN, "Group RY rotation complete ");
	}
	else
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "There is not enough objects for this command to work");
	}

	return 1;
}

// Rotate map on RX
CMD:grz(playerid, arg[])
{
    MapOpenCheck();
	new time = GetTickCount();
	new Float:Delta;
	if(sscanf(arg, "f", Delta))
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "Usage: /grz <rotation> ");
		return 1;
	}

	// We need to get the map center as the rotation node
	new bool:value, Float:gCenterX, Float:gCenterY, Float:gCenterZ;

	if(PivotPointOn[playerid])
	{
		new bool:hasgroup;
		foreach(new i : Objects)
		{
		    if(GroupedObjects[playerid][i])
		    {
			    gCenterX = PivotPoint[playerid][xPos];
			    gCenterY = PivotPoint[playerid][yPos];
			    gCenterZ = PivotPoint[playerid][zPos];
				value = true;
                hasgroup = true;
				break;
			}
		}
		if(!hasgroup)
		{
			SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
			SendClientMessage(playerid, STEALTH_YELLOW, "There is not enough objects for this command to work");
		}
	}
	else if(GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ)) value = true;

	if(value)
	{
		// Loop through all objects and perform rotation calculations
		foreach(new i : Objects)
		{
			if(GroupedObjects[playerid][i])
			{
				SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
				AttachObjectToPoint(i, gCenterX, gCenterY, gCenterZ, 0.0, 0.0, Delta, ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);
				SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);
				SetDynamicObjectRot(ObjectData[i][oID], ObjectData[i][oRX], ObjectData[i][oRY], ObjectData[i][oRZ]);

				UpdateObject3DText(i);

				sqlite_UpdateObjectPos(i);
			}
		}

   		// Update the Group GUI
		UpdatePlayerGSelText(playerid);

		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_GREEN, "Group RZ rotation complete ");
	}
	else
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "There is not enough objects for this command to work");
	}

	return 1;
}


// Export group of objects as an attached object
/*

CMD:gaexport(playerid, arg[])
{
	MapOpenCheck();

	new count;
	foreach(new i : Objects)
	{
	    if(GroupedObjects[playerid][i])
		{
			count++;
			break;
		}
	}

	if(count)
	{
	    inline CreateAttachExport(cpid, cdialogid, cresponse, clistitem, string:ctext[])
		{
		    #pragma unused clistitem, cdialogid, cpid
			if(cresponse)
		    {
				if(!isnull(ctext))
				{
					new mapname[128];
					format(mapname, sizeof(mapname), "tstudio/AttachExport/%s.txt", ctext);

					if(!fexist(mapname)) AttachExport(playerid, mapname);
					else
					{
                        inline OverwriteAttachExport(opid, odialogid, oresponse, olistitem, string:otext[])
                        {
                            #pragma unused olistitem, odialogid, opid, otext
                            
							if(oresponse)
							{
								fremove(mapname);
								AttachExport(playerid, mapname);
							}
								
						}
						SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
						SendClientMessage(playerid, STEALTH_YELLOW, "A attached object export with that name already exists");
						Dialog_ShowCallback(playerid, using inline OverwriteAttachExport, DIALOG_STYLE_MSGBOX, "Texture Studio", "Attached file exists overwrite?", "Ok", "Cancel");
					}
				}
				else
				{
					SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
					SendClientMessage(playerid, STEALTH_YELLOW, "You must give your attached export a filename");
					Dialog_ShowCallback(playerid, using inline CreateAttachExport, DIALOG_STYLE_INPUT, "Texture Studio", "Enter attached object export file", "Ok", "Cancel");
				}
		    }
		}
		Dialog_ShowCallback(playerid, using inline CreateAttachExport, DIALOG_STYLE_INPUT, "Texture Studio", "Enter attached object export file", "Ok", "Cancel");
	}
	else
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "No object to save to prefab");
	}
	return 1;
}

AttachExport(playerid, mapname[128])
{
	// Choose a object as a center node
	inline SelectObjectCenterNode(spid, sdialogid, sresponse, slistitem, string:stext[])
	{
		if(sresponse)
		{
			if(isnull(stext))
			{
				SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
				SendClientMessage(playerid, STEALTH_YELLOW, "You must provide an index as center object");
				Dialog_ShowCallback(playerid, using inline SelectObjectCenterNode, DIALOG_STYLE_INPUT, "Texture Studio", "Enter object index of attach object center", "Ok", "Cancel");
				return 1;
			}
			new centerindex = strval(stext);

			if(centerindex < 0 || centerindex > MAX_TEXTURE_OBJECTS - 1)
			{
				SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
				SendClientMessage(playerid, STEALTH_YELLOW, "Invalid index");
				Dialog_ShowCallback(playerid, using inline SelectObjectCenterNode, DIALOG_STYLE_INPUT, "Texture Studio", "Enter object index of attach object center", "Ok", "Cancel");
				return 1;
			}
			
		    if(!GroupedObjects[playerid][centerindex])
		    {
				SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
				SendClientMessage(playerid, STEALTH_YELLOW, "That object is not in your group selection");
				Dialog_ShowCallback(playerid, using inline SelectObjectCenterNode, DIALOG_STYLE_INPUT, "Texture Studio", "Enter object index of attach object center", "Ok", "Cancel");
				return 1;
		    }
		    
			// Get Offsets
		    new Float:offx, Float:offy, Float:offz;
		    offx = ObjectData[centerindex][oX];
		    offy = ObjectData[centerindex][oY];
		    offz = ObjectData[centerindex][oZ];
		    
		    
			new mobjects;
			new templine[256];
			new File:f;

			f = fopen(mapname,io_write);

			fwrite(f,"//Attached Object Map Exported with Texture Studio By: [uL]Pottus////////////////////////////////////////////////\r\n");
			fwrite(f,"/////////////////////////////////////////////////////////////////////////////////////////////////////////////////\r\n");
			fwrite(f,"/////////////////////////////////////////////////////////////////////////////////////////////////////////////////\r\n");

			new count;


			foreach(new i : Objects)
			{
			    if(GroupedObjects[playerid][i])
				{
					count++;
					break;
				}
			}
		}
	}

    Dialog_ShowCallback(playerid, using inline SelectObjectCenterNode, DIALOG_STYLE_INPUT, "Texture Studio", "Enter object index of attach object center", "Ok", "Cancel");

	return 1;
}

*/

// Save objects as a prefab data base
new NewPreFabString[512];
new DB: PrefabDB;
CMD:gprefab(playerid, arg[]) // in GUI
{
	MapOpenCheck();

	new count;
	foreach(new i : Objects)
	{
	    if(GroupedObjects[playerid][i])
		{
			count++;
			break;
		}
	}

	if(count)
	{
	    inline CreatePrefab(cpid, cdialogid, cresponse, clistitem, string:ctext[])
		{
		    #pragma unused clistitem, cdialogid, cpid
			if(cresponse)
		    {
				if(!isnull(ctext))
				{
					new mapname[128];
					format(mapname, sizeof(mapname), "tstudio/PreFabs/%s.db", ctext);

					if(!fexist(mapname))
					{
						// Open the map for editing
			            PrefabDB = db_open_persistent(mapname);

						if(!NewPreFabString[0])
						{
							strimplode(" ",
								NewPreFabString,
								sizeof(NewPreFabString),
								"CREATE TABLE IF NOT EXISTS `Objects`",
								"(ModelID INTEGER,",
								"xPos REAL,",
								"yPos REAL,",
								"zPos REAL,",
								"rxRot REAL,",
								"ryRot REAL,",
								"rzRot REAL,",
								"TextureIndex TEXT,",
								"ColorIndex TEXT,",
								"usetext INTEGER,",
								"FontFace INTEGER,",
								"FontSize INTEGER,",
								"FontBold INTEGER,",
								"FontColor INTEGER,",
								"BackColor INTEGER,",
								"Alignment INTEGER,",
								"TextFontSize INTEGER,",
								"ObjectText TEXT);"
							);
						}

						db_exec(PrefabDB, NewPreFabString);

						// Prefab extra info
						db_exec(PrefabDB, "CREATE TABLE IF NOT EXISTS `PrefabInfo` (zOFF REAL);");
						db_exec(PrefabDB, "INSERT INTO `PrefabInfo` VALUES(0.0);");


						new Float:x, Float:y, Float:z;

						if(!GetGroupCenter(playerid, x, y, z))
						{
							foreach(new i : Objects)
							{
								if(GroupedObjects[playerid][i])
								{
									x = ObjectData[i][oX];
									y = ObjectData[i][oY];
									z = ObjectData[i][oZ];
									break;
								}
						    }
						}


						count = 0;

						foreach(new i : Objects)
						{
							if(GroupedObjects[playerid][i])
							{
								sqlite_InsertPrefab(i, x, y, z);
								count++;
						    }
						}


						SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
						new line[128];
						format(line, sizeof(line), "You have created a prefab Object Count: %i", count);
						SendClientMessage(playerid, STEALTH_GREEN, line);

						db_free_persistent(PrefabDB);

					}
					else
					{
						SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
						SendClientMessage(playerid, STEALTH_YELLOW, "A prefab with that name already exists");
						Dialog_ShowCallback(playerid, using inline CreatePrefab, DIALOG_STYLE_INPUT, "Texture Studio", "Enter a prefab name", "Ok", "Cancel");
					}
				}
				else
				{
					SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
					SendClientMessage(playerid, STEALTH_YELLOW, "You must give your prefab a filename");
					Dialog_ShowCallback(playerid, using inline CreatePrefab, DIALOG_STYLE_INPUT, "Texture Studio", "Enter a prefab name", "Ok", "Cancel");
				}
		    }
		}
		Dialog_ShowCallback(playerid, using inline CreatePrefab, DIALOG_STYLE_INPUT, "Texture Studio", "Enter a prefab name", "Ok", "Cancel");
	}
	else
	{
		SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
		SendClientMessage(playerid, STEALTH_YELLOW, "No object to save to prefab");
	}
	return 1;
}


// Insert object to prefab DB
new DBStatement:insertprefabstmt;
new InsertPrefabString[512];

sqlite_InsertPrefab(index, Float:x, Float:y, Float:z)
{
	// Inserts a new index
	if(!InsertPrefabString[0])
	{
		// Prepare query
		strimplode(" ",
			InsertPrefabString,
			sizeof(InsertPrefabString),
			"INSERT INTO `Objects`",
	        "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
		);
		// Prepare data base for writing
		insertprefabstmt = db_prepare(PrefabDB, InsertPrefabString);
	}

	// Bind our results
    stmt_bind_value(insertprefabstmt, 0, DB::TYPE_INT, ObjectData[index][oModel]);
    stmt_bind_value(insertprefabstmt, 1, DB::TYPE_FLOAT, ObjectData[index][oX]-x);
    stmt_bind_value(insertprefabstmt, 2, DB::TYPE_FLOAT, ObjectData[index][oY]-y);
    stmt_bind_value(insertprefabstmt, 3, DB::TYPE_FLOAT, ObjectData[index][oZ]-z);
    stmt_bind_value(insertprefabstmt, 4, DB::TYPE_FLOAT, ObjectData[index][oRX]);
    stmt_bind_value(insertprefabstmt, 5, DB::TYPE_FLOAT, ObjectData[index][oRY]);
    stmt_bind_value(insertprefabstmt, 6, DB::TYPE_FLOAT, ObjectData[index][oRZ]);
    stmt_bind_value(insertprefabstmt, 7, DB::TYPE_ARRAY, ObjectData[index][oTexIndex], MAX_MATERIALS);
    stmt_bind_value(insertprefabstmt, 8, DB::TYPE_ARRAY, ObjectData[index][oColorIndex], MAX_MATERIALS);
    stmt_bind_value(insertprefabstmt, 9, DB::TYPE_INT, ObjectData[index][ousetext]);
    stmt_bind_value(insertprefabstmt, 10, DB::TYPE_INT, ObjectData[index][oFontFace]);
    stmt_bind_value(insertprefabstmt, 11, DB::TYPE_INT, ObjectData[index][oFontSize]);
    stmt_bind_value(insertprefabstmt, 12, DB::TYPE_INT, ObjectData[index][oFontBold]);
    stmt_bind_value(insertprefabstmt, 13, DB::TYPE_INT, ObjectData[index][oFontColor]);
    stmt_bind_value(insertprefabstmt, 14, DB::TYPE_INT, ObjectData[index][oBackColor]);
    stmt_bind_value(insertprefabstmt, 15, DB::TYPE_INT, ObjectData[index][oAlignment]);
    stmt_bind_value(insertprefabstmt, 16, DB::TYPE_INT, ObjectData[index][oTextFontSize]);
    stmt_bind_value(insertprefabstmt, 17, DB::TYPE_STRING, ObjectData[index][oObjectText], MAX_TEXT_LENGTH);

    stmt_execute(insertprefabstmt);
}

CMD:prefabsetz(playerid, arg[]) // in GUI
{
	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
	if(isnull(arg)) ShowPrefabs(playerid);
	else
	{
		new Float:offset;
		new mapname[128];

		if(sscanf(arg, "s[128]f", mapname, offset)) return SendClientMessage(playerid, STEALTH_YELLOW, "You must supply a valid offset value!");

		format(mapname, sizeof(mapname), "tstudio/PreFabs/%s.db", mapname);
		if(fexist(mapname))
		{
		    PrefabDB = db_open_persistent(mapname);
			new Query[128];
			format(Query, sizeof(Query), "UPDATE `PrefabInfo` SET `zOFF` = %f;", offset);
			db_exec(PrefabDB, Query);
		    db_free_persistent(PrefabDB);
			SendClientMessage(playerid, STEALTH_GREEN, "Updated prefab Z-Load offset");
		}
		else SendClientMessage(playerid, STEALTH_YELLOW, "That prefab does not exist!");
	}

	return 1;
}

// Load a prefab specify a filename
CMD:prefab(playerid, arg[]) // in GUI
{
	MapOpenCheck();
	
	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");
	if(isnull(arg)) ShowPrefabs(playerid);
	else
	{
		new mapname[128];
		format(mapname, sizeof(mapname), "tstudio/PreFabs/%s.db", arg);
		if(fexist(mapname))
		{
		    PrefabDB = db_open_persistent(mapname);
		    sqlite_LoadPrefab(playerid);
		    db_free_persistent(PrefabDB);
			SendClientMessage(playerid, STEALTH_GREEN, "Prefab loaded and set to your group selection");
		}
		else SendClientMessage(playerid, STEALTH_YELLOW, "That prefab does not exist!");
	}

	return 1;
}

CMD:0group(playerid, arg[])
{
    MapOpenCheck();

	new Float:gCenterX, Float:gCenterY, Float:gCenterZ;
	GetGroupCenter(playerid, gCenterX, gCenterY, gCenterZ);

	new bool:hasgroup;
	new time = GetTickCount();
	
	SendClientMessage(playerid, STEALTH_ORANGE, "______________________________________________");

	foreach(new i : Objects)
	{
   		if(GroupedObjects[playerid][i])
		{
			SaveUndoInfo(i, UNDO_TYPE_EDIT, time);
			
			ObjectData[i][oX] -= gCenterX;
			ObjectData[i][oY] -= gCenterY;
			ObjectData[i][oZ] -= gCenterZ;

			SetDynamicObjectPos(ObjectData[i][oID], ObjectData[i][oX], ObjectData[i][oY], ObjectData[i][oZ]);

		    sqlite_UpdateObjectPos(i);

		    UpdateObject3DText(i);

			hasgroup = true;
		}
	}
	
	if(hasgroup) SendClientMessage(playerid, STEALTH_GREEN, "Moved grouped objects to 0,0,0");
	else SendClientMessage(playerid, STEALTH_YELLOW, "You don't have any objects grouped");
	
	return 1;
}

stock ShowPrefabs(playerid)
{
	new dir:dHandle = dir_open("./scriptfiles/tstudio/PreFabs/");
	new item[40], type;
	new line[128];
	new extension[3];
	new fcount;
	new total;

	// Create a load list
	while(dir_list(dHandle, item, type))
	{
	 	if(type != FM_DIR)
	    {
			// We need to check extension
			if(strlen(item) > 3)
			{
				format(extension, sizeof(extension), "%s%s", item[strlen(item) - 2],item[strlen(item) - 1]);

				// File is apparently a db
				if(!strcmp(extension, "db"))
				{
					format(line, sizeof(line), "%s %s,", line, item);
					fcount++;
					total++;
					if(fcount == 8)
					{
						SendClientMessage(playerid, STEALTH_YELLOW, line);
						fcount = 0;
						line = "";
					}
				}
		    }
		}
	}
	if(fcount != 0) SendClientMessage(playerid, STEALTH_YELLOW, line);
	if(total > 0)
	{
		format(line, sizeof(line), "Displaying %i prefabs", total);
		SendClientMessage(playerid, STEALTH_GREEN, line);
	}
	else SendClientMessage(playerid, STEALTH_YELLOW, "There are no prefabs to list!");
	return 1;
}

static DBStatement:loadprefabstmt;

// Loads map objects from a data base
sqlite_LoadPrefab(playerid, offset = true)
{
	// Load query stmt
	loadprefabstmt = db_prepare(PrefabDB, "SELECT * FROM `Objects`");

	new tmpobject[OBJECTINFO];

	// Bind our results
    stmt_bind_result_field(loadprefabstmt, 0, DB::TYPE_INT, tmpobject[oModel]);
    stmt_bind_result_field(loadprefabstmt, 1, DB::TYPE_FLOAT, tmpobject[oX]);
    stmt_bind_result_field(loadprefabstmt, 2, DB::TYPE_FLOAT, tmpobject[oY]);
    stmt_bind_result_field(loadprefabstmt, 3, DB::TYPE_FLOAT, tmpobject[oZ]);
    stmt_bind_result_field(loadprefabstmt, 4, DB::TYPE_FLOAT, tmpobject[oRX]);
    stmt_bind_result_field(loadprefabstmt, 5, DB::TYPE_FLOAT, tmpobject[oRY]);
    stmt_bind_result_field(loadprefabstmt, 6, DB::TYPE_FLOAT, tmpobject[oRZ]);
    stmt_bind_result_field(loadprefabstmt, 7, DB::TYPE_ARRAY, tmpobject[oTexIndex], MAX_MATERIALS);
    stmt_bind_result_field(loadprefabstmt, 8, DB::TYPE_ARRAY, tmpobject[oColorIndex], MAX_MATERIALS);
    stmt_bind_result_field(loadprefabstmt, 9, DB::TYPE_INT, tmpobject[ousetext]);
    stmt_bind_result_field(loadprefabstmt, 10, DB::TYPE_INT, tmpobject[oFontFace]);
    stmt_bind_result_field(loadprefabstmt, 11, DB::TYPE_INT, tmpobject[oFontSize]);
    stmt_bind_result_field(loadprefabstmt, 12, DB::TYPE_INT, tmpobject[oFontBold]);
    stmt_bind_result_field(loadprefabstmt, 13, DB::TYPE_INT, tmpobject[oFontColor]);
    stmt_bind_result_field(loadprefabstmt, 14, DB::TYPE_INT, tmpobject[oBackColor]);
    stmt_bind_result_field(loadprefabstmt, 15, DB::TYPE_INT, tmpobject[oAlignment]);
    stmt_bind_result_field(loadprefabstmt, 16, DB::TYPE_INT, tmpobject[oTextFontSize]);
    stmt_bind_result_field(loadprefabstmt, 17, DB::TYPE_STRING, tmpobject[oObjectText], MAX_TEXT_LENGTH);

	// Get the ZOffset
	new Query[128];
	new DBResult:r;
	new Float:zoff;
	format(Query, sizeof(Query), "SELECT * FROM `PrefabInfo`");
	r = db_query(PrefabDB, Query);
	db_get_field_assoc(r, "zOFF", Query, 128);
	zoff = floatstr(Query);
	db_free_result(r);

	new Float:px, Float:py, Float:pz, Float:fa;
	new time = GetTickCount();

	if(offset) GetPosFaInFrontOfPlayer(playerid, 2.0, px, py, pz, fa);
	else GetPlayerPos(playerid, px, py, pz);

	// Clear any grouped objects
    ClearGroup(playerid);

	// Execute query
    if(stmt_execute(loadprefabstmt))
    {
        while(stmt_fetch_row(loadprefabstmt))
        {
			new index = AddDynamicObject(tmpobject[oModel], tmpobject[oX]+px, tmpobject[oY]+py, tmpobject[oZ]+pz+zoff, tmpobject[oRX], tmpobject[oRY], tmpobject[oRZ]);

			// Set textures and colors
			for(new i = 0; i < MAX_MATERIALS; i++)
			{
                ObjectData[index][oTexIndex][i] = tmpobject[oTexIndex][i];
	            ObjectData[index][oColorIndex][i] = tmpobject[oColorIndex][i];
			}

			// Get all text settings
		   	ObjectData[index][ousetext] = tmpobject[ousetext];
		    ObjectData[index][oFontFace] = tmpobject[oFontFace];
		    ObjectData[index][oFontSize] = tmpobject[oFontSize];
		    ObjectData[index][oFontBold] = tmpobject[oFontBold];
		    ObjectData[index][oFontColor] = tmpobject[oFontColor];
		    ObjectData[index][oBackColor] = tmpobject[oBackColor];
		    ObjectData[index][oAlignment] = tmpobject[oAlignment];
		    ObjectData[index][oTextFontSize] = tmpobject[oTextFontSize];
		    ObjectData[index][oGroup] = 0;

			// Get any text string
			format(ObjectData[index][oObjectText], MAX_TEXT_LENGTH, "%s", tmpobject[oObjectText]);


			UpdateObject3DText(index, true);

			// Add new object to prefab
			GroupedObjects[playerid][index] = true;
			OnUpdateGroup3DText(index);

			// We need to update textures and materials
			UpdateMaterial(index);

			// Update the object text
			UpdateObjectText(index);

			// Save materials to material database
			sqlite_SaveMaterialIndex(index);

			// Save colors to material database
			sqlite_SaveColorIndex(index);

			// Save all text
			sqlite_SaveAllObjectText(index);
			
			SaveUndoInfo(index, UNDO_TYPE_CREATED, time);
        }

   		// Update the Group GUI
		UpdatePlayerGSelText(playerid);
		stmt_close(loadprefabstmt);
        return 1;
    }
	stmt_close(loadprefabstmt);
    return 0;
}

