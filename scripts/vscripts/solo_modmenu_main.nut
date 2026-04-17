IncludeScript("VSLib");

// ---------------------------
// State
// ---------------------------
::MM_Open <- false;
::MM_Player <- null;          // VSLib.Player who controls the menu
::MM_Menu <- null;            // VSLib.HUD.Menu instance (so we can close it)

::MM_ReopenSeq <- 0;          // used to cancel pending reopen timers

// Submenu stack (top = current page)
::MM_MenuStack <- ["ROOT"];

// print controls to chat only once per map/session
::MM_HelpShown <- false;

// ---------------------------
// Feature state
// ---------------------------
// Main Mods
::MM_GodMode <- false;
::MM_GodTargetEntIndex <- -1;

::MM_InfiniteAmmo <- false;   // (scaffold toggle; implement later)
::MM_NoReload <- false;       // (scaffold toggle; implement later)
::MM_SpeedBoost <- false;     // (scaffold toggle; implement later)

// Director / misc placeholders
::MM_DirectorRelax <- false;  // (scaffold toggle; implement later)
::MM_FunBigHead <- false;     // (scaffold toggle; implement later)

// Infected menu (per-player desired SI class)
// Stored by userid (game events provide this on spawn)
::MM_DesiredZClassByUserId <- {}; // userid(int) -> zombie class int
::MM_DesiredZNameByUserId  <- {}; // userid(int) -> display name

// ---------------------------
// Style helpers (purely cosmetic)
// ---------------------------
::MM_Badge <- function(on)
{
    return on ? "[ON ]" : "[OFF]";
};

::MM_Title <- function()
{
    // Keep titles SHORT + single line to avoid HUD clipping
    local page = ::MM_MenuStack[::MM_MenuStack.len() - 1];

    if (page == "ROOT") return "SOLO MOD MENU";
    if (page == "MAIN") return "MAIN MODS";
    if (page == "WEAP") return "WEAPON MODS";
    if (page == "DIR")  return "DIRECTOR MODS";
    if (page == "FUN")  return "FUN / CHAOS";
    if (page == "SET")  return "SETTINGS";
	if (page == "INF")  return "INFECTED MENU";
	if (page == "INFCLS") return "CHOOSE INFECTED";
    return "MOD MENU";
};

// ---------------------------
// Infected helpers
// ---------------------------
::MM_IsInfectedTeam <- function(p)
{
	if (p == null) return false;
	try { return p.GetTeam() == INFECTED; } catch (e) {}
	try { return p.GetTeam() == 3; } catch (e2) {}
	return false;
};

::MM_SetZombieClassOnEntity <- function(ent, zclass)
{
	if (ent == null) return false;
	try { NetProps.SetPropInt(ent, "m_zombieClass", zclass); return true; }
	catch (e) { printl("[ModMenu] Failed to set m_zombieClass: " + e); }
	return false;
};

::MM_QueueInfectedClass <- function(p, zclass, zname)
{
	if (p == null) return;

	if (!MM_IsInfectedTeam(p))
	{
		Utils.SayToAllDel("[ModMenu] You must be on the Infected team first (use: JOIN INFECTED TEAM)." );
		MM_Reopen(p);
		return;
	}

	// Remember desired class for this userid
	local uid = -1;
	try { uid = p.GetUserId(); } catch (e) {}
	if (uid != -1)
	{
		::MM_DesiredZClassByUserId[uid] <- zclass;
		::MM_DesiredZNameByUserId[uid]  <- zname;
	}

	// Best results are when changing class while ghost.
	// If you're not ghost, we kill you so you respawn and it applies on spawn.
	local ent = null;
	try { ent = p.GetBaseEntity(); } catch (e2) {}
	if (ent != null) MM_SetZombieClassOnEntity(ent, zclass);

	if (!p.IsGhost())
	{
		try { p.Kill(); }
		catch (e3) {
			try { if (ent != null) ent.Kill(); } catch (e4) {}
		}
		Utils.SayToAllDel("[ModMenu] Switching to " + zname + "… (respawn required)");
	}
	else
	{
		Utils.SayToAllDel("[ModMenu] Set to " + zname + " (ghost)");
	}

	MM_Reopen(p);
};

::MM_CloseMenu <- function()
{
    // Flip state first so any pending "reopen" timer will no-op
    ::MM_Open = false;
    ::MM_ReopenSeq++; // invalidate any scheduled reopen

    if (::MM_Menu != null)
    {
        try { ::MM_Menu.CloseMenu(); } catch (e) {}
        try { ::MM_Menu.Detach(); } catch (e2) {}
        ::MM_Menu = null;
    }
};

::MM_ToggleMenu <- function(p = null)
{
    if (::MM_Open)
    {
        MM_CloseMenu();
        return;
    }

    // Resolve player if not provided
    if (p == null)
    {
        local humans = Players.Humans();
        if (humans.len() > 0) p = humans[0];
        else p = Players.AnyPlayer();
    }

    if (p == null) return;

    // Reset to root on open (feels nicer)
    ::MM_MenuStack = ["ROOT"];
    MM_ShowMenu(p);
};

// ---------------------------
// Submenu helpers
// ---------------------------
::MM_PushPage <- function(page)
{
    if (page == null) return;
    ::MM_MenuStack.append(page);
};

::MM_PopPage <- function()
{
    if (::MM_MenuStack.len() > 1)
        ::MM_MenuStack.remove(::MM_MenuStack.len() - 1);
};

// ---------------------------
// God Mode helpers
// ---------------------------
::MM_SetGodOnEntity <- function(ent, enabled)
{
    if (ent == null) return;

    // 0 = no damage, 2 = normal damage
    try { NetProps.SetPropInt(ent, "m_takedamage", enabled ? 0 : 2); }
    catch (e) { printl("[ModMenu] Failed to set m_takedamage: " + e); }
};

// ---------------------------
// Small utility actions (safe, minimal)
// ---------------------------
::MM_HealToFull <- function(p)
{
    if (p == null) return;
    local ent = null;
    try { ent = p.GetBaseEntity(); } catch (e) {}
    if (ent == null) return;

    // Works for survivors; harmless for infected (no-op-ish).
    try { NetProps.SetPropInt(ent, "m_iHealth", 100); } catch (e1) {}
    try { NetProps.SetPropFloat(ent, "m_healthBuffer", 0.0); } catch (e2) {}
    try { NetProps.SetPropFloat(ent, "m_healthBufferTime", 0.0); } catch (e3) {}
};

// ---------------------------
// Menu
// ---------------------------
::MM_ShowMenu <- function(p) // p must be VSLib.Player
{
    if (p == null) return;

    // If a menu is already up, close it cleanly before re-opening
    MM_CloseMenu();

    ::MM_Open = true;
    ::MM_Player = p;

    local m = HUD.Menu();
    ::MM_Menu = m;

    // Title depends on current submenu
    m.SetTitle(MM_Title());

    // Keep highlight markers small so they don't get clipped off-screen
    m.SetHighlightStrings("> ", "");
    m.SetOptionFormat("{option}");

    // Make sure RIGHT MOUSE always scrolls:
    // Select = LMB (ATTACK), Next = RMB (ATTACK2), Back/Prev = RELOAD (if supported)
    try { m.OverrideButtons(BUTTON_ATTACK, BUTTON_ATTACK2, BUTTON_RELOAD); }
    catch (e) {
        try { m.OverrideButtons(BUTTON_ATTACK, BUTTON_ATTACK2); } catch (e2) {}
    }

    // Tell controls once (solo-friendly)
    if (!::MM_HelpShown)
    {
        ::MM_HelpShown = true;
        Utils.SayToAllDel("[ModMenu] RMB=Next | LMB=Select | Reload=Back/Prev | F6/!mm=Close");
    }

    // Build options per page
    local page = ::MM_MenuStack[::MM_MenuStack.len() - 1];

    if (page == "ROOT")
    {
        m.AddOption("MAIN MODS", MM_GotoMain);
		m.AddOption("INFECTED MENU", MM_GotoInf);
        m.AddOption("WEAPON MODS", MM_GotoWeap);
        m.AddOption("DIRECTOR MODS", MM_GotoDir);
        m.AddOption("FUN / CHAOS", MM_GotoFun);
        m.AddOption("SETTINGS", MM_GotoSet);
        m.AddOption("STATUS (chat)", MM_Status);
        m.AddOption("CLOSE", MM_CloseOption);
    }
    else if (page == "MAIN")
    {
        m.AddOption("GOD MODE      " + MM_Badge(::MM_GodMode), MM_ToggleGodMode);
        m.AddOption("HEAL TO FULL", MM_DoHeal);
        m.AddOption("INFINITE AMMO " + MM_Badge(::MM_InfiniteAmmo), MM_ToggleInfiniteAmmo);
        m.AddOption("NO RELOAD     " + MM_Badge(::MM_NoReload), MM_ToggleNoReload);
        m.AddOption("SPEED BOOST   " + MM_Badge(::MM_SpeedBoost), MM_ToggleSpeedBoost);
        m.AddOption("BACK", MM_Back);
        m.AddOption("CLOSE", MM_CloseOption);
    }
    else if (page == "WEAP")
    {
        m.AddOption("COMING SOON", MM_ComingSoon);
        m.AddOption("BACK", MM_Back);
        m.AddOption("CLOSE", MM_CloseOption);
    }
    else if (page == "DIR")
    {
        m.AddOption("RELAX DIRECTOR " + MM_Badge(::MM_DirectorRelax), MM_ToggleDirectorRelax);
        m.AddOption("COMING SOON", MM_ComingSoon);
        m.AddOption("BACK", MM_Back);
        m.AddOption("CLOSE", MM_CloseOption);
    }
    else if (page == "FUN")
    {
        m.AddOption("BIG HEAD MODE " + MM_Badge(::MM_FunBigHead), MM_ToggleBigHead);
        m.AddOption("COMING SOON", MM_ComingSoon);
        m.AddOption("BACK", MM_Back);
        m.AddOption("CLOSE", MM_CloseOption);
    }
    else if (page == "SET")
    {
        m.AddOption("RESET TO ROOT", MM_ResetRoot);
        m.AddOption("BACK", MM_Back);
        m.AddOption("CLOSE", MM_CloseOption);
    }
	else if (page == "INF")
	{
		m.AddOption("JOIN INFECTED TEAM", MM_JoinInfected);
		m.AddOption("CHANGE CLASS", MM_GotoInfClass);
		m.AddOption("SUICIDE / RESPAWN", MM_InfectedSuicide);
		m.AddOption("BACK", MM_Back);
		m.AddOption("CLOSE", MM_CloseOption);
	}
	else if (page == "INFCLS")
	{
		m.AddOption("SMOKER",  MM_BecomeSmoker);
		m.AddOption("BOOMER",  MM_BecomeBoomer);
		m.AddOption("HUNTER",  MM_BecomeHunter);
		m.AddOption("SPITTER", MM_BecomeSpitter);
		m.AddOption("JOCKEY",  MM_BecomeJockey);
		m.AddOption("CHARGER", MM_BecomeCharger);
		m.AddOption("TANK (may fail)", MM_BecomeTank);
		m.AddOption("BACK", MM_Back);
		m.AddOption("CLOSE", MM_CloseOption);
	}
    else
    {
        m.AddOption("BACK", MM_Back);
        m.AddOption("CLOSE", MM_CloseOption);
    }

    // Use a left/top anchor if available to avoid any center-box clipping on some HUD scales.
    local pos = ("HUD_LEFT_TOP" in getroottable()) ? HUD_LEFT_TOP : HUD_MID_BOX;

    // DisplayMenu(player, attachTo, autoDetach=false, resize=true)
    m.DisplayMenu(p, pos, false);
};

// Menu closes on select by design, so we reopen after the callback.
// IMPORTANT: we cancel/guard this so pressing F6 right after a selection
// doesn't cause the menu to "re-open by itself".
::MM_ThinkEnt <- null;

// Returns an entity handle we can safely attach SetContextThink() to.
// Player entities can be finicky across builds; worldspawn is reliable.
::MM_GetThinkEnt <- function()
{
    if (::MM_ThinkEnt != null) return ::MM_ThinkEnt;

    local e = null;
    try { e = Entities.FindByClassname(null, "worldspawn"); } catch (err) { e = null; }
    if (e == null)
    {
        try { e = Entities.FindByClassname(null, "info_director"); } catch (err2) { e = null; }
    }

    ::MM_ThinkEnt = e;
    return ::MM_ThinkEnt;
};

// Menu closes on select by design, so we reopen after the callback.
// IMPORTANT: we cancel/guard this so pressing F6 right after a selection
// doesn't cause the menu to "re-open by itself".
::MM_Reopen <- function(p)
{
    if (p == null) return;

    local seq = ++::MM_ReopenSeq;

    // Use SetContextThink on worldspawn (no VSLib timers; avoids the "count" error spam)
    local thinkEnt = MM_GetThinkEnt();

    // If we somehow can't get a think entity, just reopen immediately as a last resort.
    if (thinkEnt == null)
    {
        if (::MM_Open && seq == ::MM_ReopenSeq) MM_ShowMenu(p);
        return;
    }

    local pp = p; // capture
    local thinkName = "MM_ReopenThink_" + seq;

    try
    {
        // 0.12 avoids input carry-over and is above common min delays
        thinkEnt.SetContextThink(thinkName, function()
        {
            if (!::MM_Open) return -1;
            if (seq != ::MM_ReopenSeq) return -1;
            MM_ShowMenu(pp);
            return -1;
        }, 0.12);
    }
    catch (e)
    {
        // Fallback: immediate reopen (still guarded)
        if (::MM_Open && seq == ::MM_ReopenSeq) MM_ShowMenu(pp);
    }
};


// ---------------------------
// Navigation callbacks
// ---------------------------
::MM_GotoMain <- function(p, index, value) { ::MM_MenuStack = ["ROOT"]; MM_PushPage("MAIN"); MM_Reopen(p); };
::MM_GotoInf  <- function(p, index, value) { ::MM_MenuStack = ["ROOT"]; MM_PushPage("INF");  MM_Reopen(p); };
::MM_GotoWeap <- function(p, index, value) { ::MM_MenuStack = ["ROOT"]; MM_PushPage("WEAP"); MM_Reopen(p); };
::MM_GotoDir  <- function(p, index, value) { ::MM_MenuStack = ["ROOT"]; MM_PushPage("DIR");  MM_Reopen(p); };
::MM_GotoFun  <- function(p, index, value) { ::MM_MenuStack = ["ROOT"]; MM_PushPage("FUN");  MM_Reopen(p); };
::MM_GotoSet  <- function(p, index, value) { ::MM_MenuStack = ["ROOT"]; MM_PushPage("SET");  MM_Reopen(p); };

::MM_GotoInfClass <- function(p, index, value)
{
	if (!MM_IsInfectedTeam(p))
	{
		Utils.SayToAllDel("[ModMenu] Not infected yet. Use JOIN INFECTED TEAM first.");
		MM_Reopen(p);
		return;
	}
	MM_PushPage("INFCLS");
	MM_Reopen(p);
};

::MM_Back <- function(p, index, value)
{
    MM_PopPage();
    MM_Reopen(p);
};

::MM_ResetRoot <- function(p, index, value)
{
    ::MM_MenuStack = ["ROOT"];
    Utils.SayToAllDel("[ModMenu] Menu reset to ROOT.");
    MM_Reopen(p);
};

::MM_ComingSoon <- function(p, index, value)
{
    Utils.SayToAllDel("[ModMenu] Coming soon.");
    MM_Reopen(p);
};

// ---------------------------
// Feature callbacks
// ---------------------------
::MM_ToggleGodMode <- function(p, index, value)
{
    ::MM_GodMode = !::MM_GodMode;

    // remember which player toggled it
    ::MM_GodTargetEntIndex <- -1;
    try
    {
        local ent = p.GetBaseEntity();
        if (ent != null) ::MM_GodTargetEntIndex <- ent.GetEntityIndex();
    }
    catch (e) { ::MM_GodTargetEntIndex <- -1; }

    // apply immediately
    MM_SetGodOnEntity(p.GetBaseEntity(), ::MM_GodMode);

    Utils.SayToAllDel("[ModMenu] God Mode: " + (::MM_GodMode ? "ON" : "OFF"));
    MM_Reopen(p);
};

::MM_DoHeal <- function(p, index, value)
{
    MM_HealToFull(p);
    Utils.SayToAllDel("[ModMenu] Healed to full.");
    MM_Reopen(p);
};

::MM_ToggleInfiniteAmmo <- function(p, index, value)
{
    ::MM_InfiniteAmmo = !::MM_InfiniteAmmo;
    Utils.SayToAllDel("[ModMenu] Infinite Ammo: " + (::MM_InfiniteAmmo ? "ON" : "OFF") + " (scaffold)");
    MM_Reopen(p);
};

::MM_ToggleNoReload <- function(p, index, value)
{
    ::MM_NoReload = !::MM_NoReload;
    Utils.SayToAllDel("[ModMenu] No Reload: " + (::MM_NoReload ? "ON" : "OFF") + " (scaffold)");
    MM_Reopen(p);
};

::MM_ToggleSpeedBoost <- function(p, index, value)
{
    ::MM_SpeedBoost = !::MM_SpeedBoost;
    Utils.SayToAllDel("[ModMenu] Speed Boost: " + (::MM_SpeedBoost ? "ON" : "OFF") + " (scaffold)");
    MM_Reopen(p);
};

::MM_ToggleDirectorRelax <- function(p, index, value)
{
    ::MM_DirectorRelax = !::MM_DirectorRelax;
    Utils.SayToAllDel("[ModMenu] Director Relax: " + (::MM_DirectorRelax ? "ON" : "OFF") + " (scaffold)");
    MM_Reopen(p);
};

::MM_ToggleBigHead <- function(p, index, value)
{
    ::MM_FunBigHead = !::MM_FunBigHead;
    Utils.SayToAllDel("[ModMenu] Big Head Mode: " + (::MM_FunBigHead ? "ON" : "OFF") + " (scaffold)");
    MM_Reopen(p);
};

// ---------------------------
// Infected callbacks
// ---------------------------
::MM_JoinInfected <- function(p, index, value)
{
	// Only works when jointeam is allowed (local server / versus/scavenge/mutation etc.)
	try { p.ClientCommand("jointeam 3"); } catch (e) {}
	Utils.SayToAllDel("[ModMenu] Attempted to join Infected team.");
	MM_Reopen(p);
};

::MM_InfectedSuicide <- function(p, index, value)
{
	if (!MM_IsInfectedTeam(p))
	{
		Utils.SayToAllDel("[ModMenu] You're not on the Infected team.");
		MM_Reopen(p);
		return;
	}
	try { p.Kill(); }
	catch (e) { try { p.GetBaseEntity().Kill(); } catch (e2) {} }
	Utils.SayToAllDel("[ModMenu] Respawning…");
	MM_Reopen(p);
};

// Standard L4D2 zombie class values:
// 1 Smoker, 2 Boomer, 3 Hunter, 4 Spitter, 5 Jockey, 6 Charger, 7 Witch, 8 Tank
::MM_BecomeSmoker  <- function(p, i, v) { MM_QueueInfectedClass(p, 1, "Smoker"); };
::MM_BecomeBoomer  <- function(p, i, v) { MM_QueueInfectedClass(p, 2, "Boomer"); };
::MM_BecomeHunter  <- function(p, i, v) { MM_QueueInfectedClass(p, 3, "Hunter"); };
::MM_BecomeSpitter <- function(p, i, v) { MM_QueueInfectedClass(p, 4, "Spitter"); };
::MM_BecomeJockey  <- function(p, i, v) { MM_QueueInfectedClass(p, 5, "Jockey"); };
::MM_BecomeCharger <- function(p, i, v) { MM_QueueInfectedClass(p, 6, "Charger"); };
::MM_BecomeTank    <- function(p, i, v) { MM_QueueInfectedClass(p, 8, "Tank"); };

// ---------------------------
// Status / Close
// ---------------------------
::MM_Status <- function(p, index, value)
{
    Utils.SayToAllDel(
        "[ModMenu] GOD=" + (::MM_GodMode ? "ON" : "OFF") +
        " | AMMO=" + (::MM_InfiniteAmmo ? "ON" : "OFF") +
        " | NR=" + (::MM_NoReload ? "ON" : "OFF") +
        " | SPD=" + (::MM_SpeedBoost ? "ON" : "OFF")
    );
    MM_Reopen(p);
};

::MM_CloseOption <- function(p, index, value)
{
    MM_CloseMenu();
};

// ---------------------------
// Spawn hook
// - re-apply God Mode
// - apply queued infected class
// ---------------------------
function OnGameEvent_player_spawn(params)
{
	if (!("userid" in params)) return;

	local ent = GetPlayerFromUserID(params.userid);
	if (ent == null) return;

	// 1) Re-apply God Mode
	if (::MM_GodMode)
	{
		if (::MM_GodTargetEntIndex == -1)
		{
			MM_SetGodOnEntity(ent, true);
		}
		else
		{
			try { if (ent.GetEntityIndex() == ::MM_GodTargetEntIndex) MM_SetGodOnEntity(ent, true); }
			catch (e) {}
		}
	}

	// 2) Apply queued infected class (if any)
	if (params.userid in ::MM_DesiredZClassByUserId)
	{
		local team = -1;
		try { team = NetProps.GetPropInt(ent, "m_iTeamNum"); } catch (e2) {}
		if (team == 3)
		{
			local zc = ::MM_DesiredZClassByUserId[params.userid];
			MM_SetZombieClassOnEntity(ent, zc);
		}
	}
}

// ---------------------------
// Chat hook (survivor OR infected)
// !mm toggles open/close
// ---------------------------
function OnGameEvent_player_say(params)
{
    if (!("text" in params)) return;

    local msg = params.text.tolower();
    if (msg != "!mm" && msg != "!menu") return;

    // Resolve speaker -> VSLib.Player (HUD.Menu requires VSLib.Player)
    local ent = null;
    if ("userid" in params) ent = GetPlayerFromUserID(params.userid);

    local p = null;

    if (ent != null)
    {
        foreach (pl in Players.All())
        {
            if (pl != null && pl.GetBaseEntity() == ent)
            {
                p = pl;
                break;
            }
        }
    }

    // Fallbacks
    if (p == null)
    {
        local humans = Players.Humans();
        if (humans.len() > 0) p = humans[0];
        else p = Players.AnyPlayer();
    }

    if (p == null) return;

    MM_ToggleMenu(p);
}

// Register events once
if (!("MM_EventsRegistered" in getroottable()))
{
    ::MM_EventsRegistered <- true;

    if ("__CollectEventCallbacks" in getroottable())
    {
        __CollectEventCallbacks(this, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
        printl("[ModMenu] Loaded. Say !mm (or press F6).");
    }
}
