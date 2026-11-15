/*
 * IRCx-style PROP command with OWNERKEY / HOSTKEY support
 *
 * Adds /PROP #channel OWNERKEY|HOSTKEY [:<value>]
 * When a user JOINs with a matching key they receive +q (owner) or +o (host/op).
 *
 * OWNERKEY / HOSTKEY are never readable (IRCx behaviour).
 * Only channel owners (+q) may set/clear OWNERKEY.
 * Channel operators (+o or +q) may set/clear HOSTKEY.
 *
 * Compatible with UnrealIRCd 6.x module API.
 *
 * (C) 2026 - IRCx compatibility module
 */

#include "unrealircd.h"

#define MYCONF "ircxprop"
#define IRCX_KEYLEN 31		/* IRCx limit */

ModuleHeader MOD_HEADER = {
	"third/ircx_prop",
	"1.0.0",
	"IRCx PROP with OWNERKEY and HOSTKEY (auto-op/owner on JOIN)",
	"IRCx compat",
	"unrealircd-6",
};

/* ModData slots */
static ModDataInfo *md_ownerkey = NULL;
static ModDataInfo *md_hostkey = NULL;

/* Temporary storage of intended modes for the current join (per-client) */
static ModDataInfo *md_pending_modes = NULL;

/* Forward declarations */
CMD_FUNC(cmd_prop);
static int ircxprop_can_join(Client *client, Channel *channel, const char *key, char **errmsg);
static int ircxprop_local_join(Client *client, Channel *channel, MessageTag *mtags);
static void free_key_md(ModData *m);
static const char *serialize_key_md(ModData *m);
static void unserialize_key_md(const char *str, ModData *m);
static void free_pending_md(ModData *m);

/* Helpers */
static const char *get_ownerkey(Channel *channel)
{
	return moddata_channel(channel, md_ownerkey).str;
}

static const char *get_hostkey(Channel *channel)
{
	return moddata_channel(channel, md_hostkey).str;
}

static void set_key_md(Channel *channel, ModDataInfo *md, const char *value)
{
	if (moddata_channel(channel, md).str)
		safe_free(moddata_channel(channel, md).str);

	if (value && *value)
		moddata_channel(channel, md).str = strdup(value);
	else
		moddata_channel(channel, md).str = NULL;
}

static int is_valid_ircx_key(const char *key)
{
	const char *p;
	size_t len;

	if (!key)
		return 0;
	len = strlen(key);
	if (len == 0 || len > IRCX_KEYLEN)
		return 0;
	for (p = key; *p; p++)
	{
		/* IRCx keys are fairly permissive; reject control chars and space/comma/colon for safety */
		if ((unsigned char)*p <= 32 || *p == ',' || *p == ':')
			return 0;
	}
	return 1;
}

/* ========== Module lifecycle ========== */

MOD_INIT()
{
	ModDataInfo mreq;

	MARK_AS_OFFICIAL_MODULE(modinfo); /* not really official, but silences some warnings */

	/* OWNERKEY storage */
	memset(&mreq, 0, sizeof(mreq));
	mreq.type = MODDATATYPE_CHANNEL;
	mreq.name = "ircx_ownerkey";
	mreq.free = free_key_md;
	mreq.serialize = serialize_key_md;
	mreq.unserialize = unserialize_key_md;
	mreq.sync = MODDATA_SYNC_EARLY;
	md_ownerkey = ModDataAdd(modinfo->handle, mreq);
	if (!md_ownerkey)
	{
		config_error("ircx_prop: failed to add ownerkey moddata");
		return MOD_FAILED;
	}

	/* HOSTKEY storage */
	memset(&mreq, 0, sizeof(mreq));
	mreq.type = MODDATATYPE_CHANNEL;
	mreq.name = "ircx_hostkey";
	mreq.free = free_key_md;
	mreq.serialize = serialize_key_md;
	mreq.unserialize = unserialize_key_md;
	mreq.sync = MODDATA_SYNC_EARLY;
	md_hostkey = ModDataAdd(modinfo->handle, mreq);
	if (!md_hostkey)
	{
		config_error("ircx_prop: failed to add hostkey moddata");
		return MOD_FAILED;
	}

	/* Temporary pending modes for the joining client */
	memset(&mreq, 0, sizeof(mreq));
	mreq.type = MODDATATYPE_LOCAL_CLIENT;
	mreq.name = "ircx_pending_modes";
	mreq.free = free_pending_md;
	md_pending_modes = ModDataAdd(modinfo->handle, mreq);
	if (!md_pending_modes)
	{
		config_error("ircx_prop: failed to add pending_modes moddata");
		return MOD_FAILED;
	}

	CommandAdd(modinfo->handle, "PROP", cmd_prop, MAXPARA, CMD_USER);

	/* We look at the key during can_join so we can decide the privilege level */
	HookAdd(modinfo->handle, HOOKTYPE_CAN_JOIN, 0, ircxprop_can_join);
	/* After the user has joined we apply +q / +o */
	HookAdd(modinfo->handle, HOOKTYPE_LOCAL_JOIN, 0, ircxprop_local_join);

	return MOD_SUCCESS;
}

MOD_LOAD()
{
	return MOD_SUCCESS;
}

MOD_UNLOAD()
{
	return MOD_SUCCESS;
}

/* ========== ModData helpers ========== */

static void free_key_md(ModData *m)
{
	safe_free(m->str);
}

static const char *serialize_key_md(ModData *m)
{
	return m->str; /* may be NULL */
}

static void unserialize_key_md(const char *str, ModData *m)
{
	safe_free(m->str);
	if (str && *str)
		m->str = strdup(str);
}

static void free_pending_md(ModData *m)
{
	safe_free(m->str);
}

/* ========== PROP command ========== */

/*
 * PROP <channel> [<property> [:<value>]]
 *
 * Supported properties: OWNERKEY, HOSTKEY
 * (MEMBERKEY is intentionally left to the normal +k mode)
 */
CMD_FUNC(cmd_prop)
{
	Channel *channel;
	const char *prop;
	const char *value;
	int setting = 0;
	int deleting = 0;

	if (parc < 2 || BadPtr(parv[1]))
	{
		sendnumeric(client, ERR_NEEDMOREPARAMS, "PROP");
		return;
	}

	channel = find_channel(parv[1]);
	if (!channel)
	{
		sendnumeric(client, ERR_NOSUCHCHANNEL, parv[1]);
		return;
	}

	/* Must be on the channel to use PROP (IRCx-ish) */
	if (!IsMember(client, channel) && !IsOper(client))
	{
		sendnumeric(client, ERR_NOTONCHANNEL, channel->name);
		return;
	}

	if (parc < 3 || BadPtr(parv[2]))
	{
		/* PROP #chan  --> list known properties (names only, no secret values) */
		sendto_one(client, NULL, ":%s 818 %s %s OWNERKEY :", me.name, client->name, channel->name);
		sendto_one(client, NULL, ":%s 818 %s %s HOSTKEY :", me.name, client->name, channel->name);
		sendto_one(client, NULL, ":%s 819 %s %s :End of properties", me.name, client->name, channel->name);
		return;
	}

	prop = parv[2];

	/* Determine if this is a set / delete / query */
	if (parc >= 4)
	{
		value = parv[3];
		if (value[0] == ':')
			value++;			/* traditional trailing colon */
		if (!*value)
			deleting = 1;
		else
			setting = 1;
	}
	else
	{
		value = NULL;			/* pure query */
	}

	if (!strcasecmp(prop, "OWNERKEY"))
	{
		if (setting || deleting)
		{
			/* Only +q (or higher) may change OWNERKEY */
			if (!check_channel_access(client, channel, "q") && !IsOper(client))
			{
				sendnumeric(client, ERR_CHANOPRIVSNEEDED, channel->name);
				return;
			}
			if (setting && !is_valid_ircx_key(value))
			{
				sendto_one(client, NULL, ":%s 905 %s %s :Bad value specified",
				           me.name, client->name, channel->name);
				return;
			}
			set_key_md(channel, md_ownerkey, deleting ? NULL : value);
			/* IRCx does not echo the value back for security reasons */
			sendto_one(client, NULL, ":%s PROP %s OWNERKEY :%s",
			           me.name, channel->name, deleting ? "" : "*");
			/* Notify other ops on the channel that the key changed (without revealing it) */
			sendto_channel(channel, &me, NULL, "hoaq", 0, SEND_LOCAL, NULL,
			               ":%s NOTICE %s :OWNERKEY has been %s by %s",
			               me.name, channel->name,
			               deleting ? "cleared" : "changed", client->name);
		}
		else
		{
			/* Query: never reveal the key */
			sendto_one(client, NULL, ":%s 818 %s %s OWNERKEY :", me.name, client->name, channel->name);
			sendto_one(client, NULL, ":%s 819 %s %s :End of properties", me.name, client->name, channel->name);
		}
		return;
	}

	if (!strcasecmp(prop, "HOSTKEY"))
	{
		if (setting || deleting)
		{
			/* +o or +q required */
			if (!check_channel_access(client, channel, "oaq") && !IsOper(client))
			{
				sendnumeric(client, ERR_CHANOPRIVSNEEDED, channel->name);
				return;
			}
			if (setting && !is_valid_ircx_key(value))
			{
				sendto_one(client, NULL, ":%s 905 %s %s :Bad value specified",
				           me.name, client->name, channel->name);
				return;
			}
			set_key_md(channel, md_hostkey, deleting ? NULL : value);
			sendto_one(client, NULL, ":%s PROP %s HOSTKEY :%s",
			           me.name, channel->name, deleting ? "" : "*");
			sendto_channel(channel, &me, NULL, "hoaq", 0, SEND_LOCAL, NULL,
			               ":%s NOTICE %s :HOSTKEY has been %s by %s",
			               me.name, channel->name,
			               deleting ? "cleared" : "changed", client->name);
		}
		else
		{
			sendto_one(client, NULL, ":%s 818 %s %s HOSTKEY :", me.name, client->name, channel->name);
			sendto_one(client, NULL, ":%s 819 %s %s :End of properties", me.name, client->name, channel->name);
		}
		return;
	}

	/* Unknown property */
	sendto_one(client, NULL, ":%s 905 %s %s :Bad property specified",
	           me.name, client->name, channel->name);
}

/* ========== JOIN key handling ========== */

/*
 * During can_join we examine the supplied key.
 * If it matches OWNERKEY or HOSTKEY we remember the privilege we should grant
 * and let the join proceed (these keys do NOT act as a +k barrier).
 */
static int ircxprop_can_join(Client *client, Channel *channel, const char *key, char **errmsg)
{
	const char *okey, *hkey;
	char *pending = NULL;

	if (!MyUser(client) || !key || !*key)
		return HOOK_CONTINUE;

	okey = get_ownerkey(channel);
	hkey = get_hostkey(channel);

	if (okey && !strcmp(key, okey))
		pending = "q";			/* channel owner */
	else if (hkey && !strcmp(key, hkey))
		pending = "o";			/* channel operator / host */

	if (pending)
	{
		/* Stash the mode letter(s) we want to apply after the join */
		safe_free(moddata_local_client(client, md_pending_modes).str);
		moddata_local_client(client, md_pending_modes).str = strdup(pending);
	}

	return HOOK_CONTINUE;		/* never deny because of these keys */
}

/*
 * After the user has successfully joined, apply the stored privilege.
 */
static int ircxprop_local_join(Client *client, Channel *channel, MessageTag *mtags)
{
	const char *modes;
	char modebuf[8];
	char parabuf[NICKLEN + 1];

	if (!MyUser(client))
		return HOOK_CONTINUE;

	modes = moddata_local_client(client, md_pending_modes).str;
	if (!modes || !*modes)
		return HOOK_CONTINUE;

	/* Clear the temporary data immediately */
	safe_free(moddata_local_client(client, md_pending_modes).str);
	moddata_local_client(client, md_pending_modes).str = NULL;

	/* Build +q or +o targeting this user */
	snprintf(modebuf, sizeof(modebuf), "+%s", modes);
	strlcpy(parabuf, client->name, sizeof(parabuf));

	/* Use the server as the mode source so it looks clean */
	set_channel_mode(channel, NULL, modebuf, parabuf);

	return HOOK_CONTINUE;
}
