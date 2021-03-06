// AE 2-16-10: added this to the workflow, it comes from the same file name in MP, this is a slimmed down version
#include common_scripts\utility;
#include maps\_utility;

init()
{
	level thread on_player_connect();

	// TODO: put weapon init's here
	maps\_flashgrenades::main();
	maps\_weaponobjects::init();
	maps\_explosive_bolt::init();
	maps\_flamethrower_plight::init();
	maps\_ballistic_knife::init();
}

on_player_connect()
{
	while( true )
	{
		level waittill("connecting", player);

		player.usedWeapons = false;
		player.hits = 0;

		player thread on_player_spawned();
	}
}

on_player_spawned()
{
	self endon("disconnect");
	self endon("death");
	
	self.usedWeapons = false;
	self.hits = 0;

	while( true )
	{
		self waittill("spawned_player");

		self thread watch_weapon_usage();
		self thread watch_grenade_usage();
	}
}

watch_weapon_usage()
{
	self endon( "death" );
	self endon( "disconnect" );
	level endon ( "game_ended" );
	
	while( true )
	{	
		self waittill ( "begin_firing" );
		
		curWeapon = self GetCurrentWeapon();
		
		switch ( WeaponClass( curWeapon ) )
		{
			case "rifle":
			case "pistol":
			case "mg":
			case "smg":
			case "spread":
				break;
			case "rocketlauncher":
			case "grenade":
				if ( WeaponInventoryType( curWeapon ) != "item" )
				{
					self thread maps\_shellshock::rocket_earthQuake();
				}
				break;
			default:
				break;
		}
		self waittill ( "end_firing" );
	}
}

watch_grenade_usage()
{
	self endon( "death" );
	self endon( "disconnect" );
	
	self thread begin_other_grenade_tracking();

	while( true )
	{
		self waittill ( "grenade_pullback", weaponName );

		 if ( weaponName == "claymore_mp" )
		 {
			 continue;
		 }

		self begin_grenade_tracking();
	}
}

begin_grenade_tracking()
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	startTime = GetTime();
	
	self waittill ( "grenade_fire", grenade, weaponName );
	
	if ( (getTime() - startTime > 1000) )
	{
		grenade.isCooked = true;
	}
	
	switch( weaponName )
	{
	case "frag_grenade_sp":
	case "sticky_grenade_mp":
		grenade thread maps\_shellshock::grenade_earthQuake();
		grenade.originalOwner = self;
		break;
	case "satchel_charge_mp":
		grenade thread maps\_shellshock::satchel_earthQuake();
		break;
	case "c4_mp":
		grenade thread maps\_shellshock::c4_earthQuake();
		break;
	}
		
	self.throwingGrenade = false;
}

begin_other_grenade_tracking()
{
	self notify( "grenadeTrackingStart" );
	self endon( "grenadeTrackingStart" );
	self endon( "disconnect" );
	
	while( true )
	{
		self waittill ( "grenade_fire", grenade, weaponName, parent );
		
		switch( weaponName )
		{
		case "flash_grenade_sp":
			break;
		case "signal_flare_mp":
			break;
		case "tabun_gas_mp":
			break;
		case "vc_grenade_sp":
			break;
		case "willy_pete_sp":
		case "m8_orange_smoke_sp":
		    grenade thread watchSmokeGrenadeDetonation();
			break;
		case "sticky_grenade_mp":
		case "satchel_charge_mp":
		case "c4_mp":
			break;
		}
	}
}


// these functions are used with scripted weapons (like satchels, shoeboxs, artillery)
// returns an array of objects representing damageable entities (including players) within a given sphere.
// each object has the property damageCenter, which represents its center (the location from which it can be damaged).
// each object also has the property entity, which contains the entity that it represents.
// to damage it, call damageEnt() on it.
getDamageableEnts(pos, radius, doLOS, startRadius)
{
	ents = [];
	
	if (!isdefined(doLOS))
		doLOS = false;
		
	if ( !isdefined( startRadius ) )
		startRadius = 0;
	
	// players
	players = GetPlayers();
	for (i = 0; i < players.size; i++)
	{
		if (!isalive(players[i]) || players[i].sessionstate != "playing")
			continue;
		
		playerpos = players[i].origin + (0,0,32);
		dist = distance(pos, playerpos);
		if (dist < radius && (!doLOS || weaponDamageTracePassed(pos, playerpos, startRadius, undefined)))
		{
			newent = spawnstruct();
			newent.isPlayer = true;
			newent.isADestructable = false;
			newent.entity = players[i];
			newent.damageCenter = playerpos;
			ents[ents.size] = newent;
		}
	}
	
	// AI
	guys = getAIarray("axis", "allies", "neutral");
	for (i = 0; i < guys.size; i++)
	{
		entpos = guys[i].origin;
		dist = distance(pos, entpos);
		if (dist < radius && (!doLOS || weaponDamageTracePassed(pos, entpos, startRadius, guys[i])))
		{
			newent = spawnstruct();
			newent.isPlayer = false;
			newent.isADestructable = false;
			newent.entity = guys[i];
			newent.damageCenter = entpos;
			ents[ents.size] = newent;
		}
	}


	// grenades
	grenades = getentarray("grenade", "classname");
	for (i = 0; i < grenades.size; i++)
	{
		entpos = grenades[i].origin;
		dist = distance(pos, entpos);
		if (dist < radius && (!doLOS || weaponDamageTracePassed(pos, entpos, startRadius, grenades[i])))
		{
			newent = spawnstruct();
			newent.isPlayer = false;
			newent.isADestructable = false;
			newent.entity = grenades[i];
			newent.damageCenter = entpos;
			ents[ents.size] = newent;
		}
	}
	
	destructibles = getentarray("destructible", "targetname");
	for (i = 0; i < destructibles.size; i++)
	{
		entpos = destructibles[i].origin;
		dist = distance(pos, entpos);
		if (dist < radius && (!doLOS || weaponDamageTracePassed(pos, entpos, startRadius, destructibles[i])))
		{
			newent = spawnstruct();
			newent.isPlayer = false;
			newent.isADestructable = false;
			newent.entity = destructibles[i];
			newent.damageCenter = entpos;
			ents[ents.size] = newent;
		}
	}

	destructables = getentarray("destructable", "targetname");
	for (i = 0; i < destructables.size; i++)
	{
		entpos = destructables[i].origin;
		dist = distance(pos, entpos);
		if (dist < radius && (!doLOS || weaponDamageTracePassed(pos, entpos, startRadius, destructables[i])))
		{
			newent = spawnstruct();
			newent.isPlayer = false;
			newent.isADestructable = true;
			newent.entity = destructables[i];
			newent.damageCenter = entpos;
			ents[ents.size] = newent;
		}
	}
	
	return ents;
}

weaponDamageTracePassed(from, to, startRadius, ignore)
{
	midpos = undefined;
	
	diff = to - from;
	if ( lengthsquared( diff ) < startRadius*startRadius )
		midpos = to;
	dir = vectornormalize( diff );
	midpos = from + (dir[0]*startRadius, dir[1]*startRadius, dir[2]*startRadius);

	trace = bullettrace(midpos, to, false, ignore);
	
//	if ( GetDvarInt( #"scr_damage_debug") != 0 )
//	{
//		if (trace["fraction"] == 1)
//		{
//			thread debugline(midpos, to, (1,1,1));
//		}
//		else
//		{
//			thread debugline(midpos, trace["position"], (1,.9,.8));
//			thread debugline(trace["position"], to, (1,.4,.3));
//		}
//	}
	
	return (trace["fraction"] == 1);
}

// eInflictor = the entity that causes the damage (e.g. a shoebox)
// eAttacker = the player that is attacking
// iDamage = the amount of damage to do
// sMeansOfDeath = string specifying the method of death (e.g. "MOD_PROJECTILE_SPLASH")
// sWeapon = string specifying the weapon used (e.g. "mine_shoebox_mp")
// damagepos = the position damage is coming from
// damagedir = the direction damage is moving in
damageEnt(eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, damagepos, damagedir)
{
	if (self.isPlayer)
	{
		self.damageOrigin = damagepos;
		self.entity thread [[level.callbackPlayerDamage]](
			eInflictor, // eInflictor The entity that causes the damage.(e.g. a turret)
			eAttacker, // eAttacker The entity that is attacking.
			iDamage, // iDamage Integer specifying the amount of damage done
			0, // iDFlags Integer specifying flags that are to be applied to the damage
			sMeansOfDeath, // sMeansOfDeath Integer specifying the method of death
			sWeapon, // sWeapon The weapon number of the weapon used to inflict the damage
			damagepos, // vPoint The point the damage is from?
			damagedir, // vDir The direction of the damage
			"none", // sHitLoc The location of the hit
			0,	// modelIndex ???
			0 // psOffsetTime The time offset for the damage
		);
	}
	else if ( IsAlive( self.entity ) )
	{
		// AIs should go through DoDamage and not use the "damage" notify directly
		self.entity DoDamage( iDamage, damagepos, eAttacker, eInflictor, sMeansOfDeath, 0 );
	}
	else
	{
		// destructable walls and such can only be damaged in certain ways.
		if (self.isADestructable && (sWeapon == "artillery_mp" || sWeapon == "mine_bouncing_betty_mp"))
			return;
		
		self.entity damage_notify_wrapper( iDamage, eAttacker, (0,0,0), (0,0,0), "mod_explosive", "", "" );
	}
}

watchSmokeGrenadeDetonation()
{
    self waittill( "explode", position, surface );
    
    smokeSound = spawn ("script_origin",(0,0,1));
	smokeSound.origin = position;
	
	//playsoundatposition( "wpn_smoke_grenade_explode", position );
	smokeSound playsound( "wpn_smoke_hiss_start" );
	smokeSound playLoopSound ( "wpn_smoke_hiss_lp" );
	wait(6);
	playsoundatposition( "wpn_smoke_hiss_end", position );	
	smokeSound StopLoopSound( .5);
	wait(.5);
	smokeSound delete();
}

