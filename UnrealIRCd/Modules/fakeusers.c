/*
 * fakeusers - Load-test module for UnrealIRCd 6
 *
 * Creates large numbers of realistic-looking fake users so you can
 * stress-test your UnrealIRCd, SNOTICE handling, channel bots and
 * gatekeeper scripts (like the mIRC usertracker you showed).
 *
 * Commands (IRC operators only):
 *   FAKEUSERS <count> [joinchance]
 *       Create <count> fake users (max 25000).
 *       joinchance = percentage that randomly join existing channels (0-100, default 15)
 *
 *   FAKEUSERS CLEAR
 *       Quit all fake users created by this module.
 *
 *   FAKEUSERS STATUS
 *       Show how many fake users are currently online.
 *
 * The users look realistic:
 *   - Common first/last name combinations + numbers
 *   - Believable realnames
 *   - Random public IPv4 addresses
 *   - Sensible idents
 *
 * They are introduced as remote users (uplink = &me) so they do not
 * consume local class slots or file descriptors, but they still appear
 * in /LUSERS, /WHO, channels and most hooks/SNOTICEs.
 *
 * (C) 2026 - for IRCPlus load testing
 */

#include "unrealircd.h"

#define MYNAME "third/fakeusers"
#define MAX_FAKEUSERS 25000
#define BATCH_SIZE 50          /* create this many per event tick to avoid lag */

ModuleHeader MOD_HEADER = {
	"third/fakeusers",
	"1.0.0",
	"Create realistic fake users for load testing",
	"IRCPlus",
	"unrealircd-6",
};

/* We tag every fake client with this moddata so we can find & clean them later */
static ModDataInfo *md_fake = NULL;

/* Generation state for batched creation */
static int gen_remaining = 0;
static int gen_joinchance = 15;
static Event *gen_event = NULL;

/* ---------- Realistic name data ---------- */

static const char *first_names[] = {
	"James","John","Robert","Michael","William","David","Richard","Joseph","Thomas","Charles",
	"Christopher","Daniel","Matthew","Anthony","Mark","Donald","Steven","Paul","Andrew","Joshua",
	"Kenneth","Kevin","Brian","George","Timothy","Ronald","Edward","Jason","Jeffrey","Ryan",
	"Jacob","Gary","Nicholas","Eric","Jonathan","Stephen","Larry","Justin","Scott","Brandon",
	"Benjamin","Samuel","Raymond","Gregory","Frank","Alexander","Patrick","Jack","Dennis","Jerry",
	"Tyler","Aaron","Jose","Adam","Nathan","Henry","Douglas","Zachary","Peter","Kyle",
	"Noah","Ethan","Jeremy","Walter","Christian","Keith","Roger","Terry","Austin","Sean",
	"Gerald","Carl","Harold","Dylan","Arthur","Lawrence","Jordan","Jesse","Bryan","Billy",
	"Bruce","Gabriel","Joe","Logan","Albert","Willie","Alan","Eugene","Russell","Vincent",
	"Philip","Bobby","Johnny","Bradley","Mary","Patricia","Jennifer","Linda","Elizabeth","Barbara",
	"Susan","Jessica","Sarah","Karen","Nancy","Lisa","Betty","Margaret","Sandra","Ashley",
	"Kimberly","Emily","Donna","Michelle","Dorothy","Carol","Amanda","Melissa","Deborah","Stephanie",
	"Rebecca","Sharon","Laura","Cynthia","Kathleen","Amy","Angela","Shirley","Anna","Brenda",
	"Pamela","Emma","Nicole","Helen","Samantha","Katherine","Christine","Debra","Rachel","Carolyn",
	"Janet","Catherine","Maria","Heather","Diane","Ruth","Julie","Olivia","Joyce","Virginia",
	"Victoria","Kelly","Lauren","Christina","Joan","Evelyn","Judith","Megan","Andrea","Cheryl",
	"Hannah","Jacqueline","Martha","Gloria","Teresa","Ann","Sara","Madison","Frances","Kathryn",
	"Janice","Jean","Abigail","Alice","Judy","Sophia","Grace","Denise","Amber","Doris",
	"Marilyn","Danielle","Beverly","Isabella","Theresa","Diana","Natalie","Brittany","Charlotte","Marie",
	NULL
};

static const char *last_names[] = {
	"Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez",
	"Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin",
	"Lee","Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson",
	"Walker","Young","Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores",
	"Green","Adams","Nelson","Baker","Hall","Rivera","Campbell","Mitchell","Carter","Roberts",
	"Gomez","Phillips","Evans","Turner","Diaz","Parker","Cruz","Edwards","Collins","Reyes",
	"Stewart","Morris","Morales","Murphy","Cook","Rogers","Gutierrez","Ortiz","Morgan","Cooper",
	"Peterson","Bailey","Reed","Kelly","Howard","Ramos","Kim","Cox","Ward","Richardson",
	"Watson","Brooks","Chavez","Wood","James","Bennett","Gray","Mendoza","Ruiz","Hughes",
	"Price","Alvarez","Castillo","Sanders","Patel","Myers","Long","Ross","Foster","Jimenez",
	NULL
};

static const char *ident_bases[] = {
	"user","pc","desktop","laptop","android","iphone","home","work","mail","web",
	"admin","guest","client","host","box","node","dev","test","irc","chat",
	NULL
};

/* ---------- Helpers ---------- */

static int is_fake_client(Client *client)
{
	if (!client || !IsUser(client))
		return 0;
	return moddata_client(client, md_fake).i ? 1 : 0;
}

static void mark_fake(Client *client)
{
	moddata_client(client, md_fake).i = 1;
}

static const char *pick(const char **list)
{
	int n = 0;
	while (list[n])
		n++;
	if (n == 0)
		return "User";
	return list[getrandom8() % n];
}

/* Generate a realistic nick: Firstname + optional digits / underscore + last initial etc. */
static void make_realistic_nick(char *buf, size_t buflen)
{
	const char *first = pick(first_names);
	const char *last  = pick(last_names);
	int style = getrandom8() % 12;
	char tmp[NICKLEN + 1];

	switch (style)
	{
		case 0:  /* John */
			strlcpy(tmp, first, sizeof(tmp));
			break;
		case 1:  /* John23 */
			snprintf(tmp, sizeof(tmp), "%s%d", first, 1 + (getrandom8() % 99));
			break;
		case 2:  /* John_Smith */
			snprintf(tmp, sizeof(tmp), "%s_%s", first, last);
			break;
		case 3:  /* JohnS */
			snprintf(tmp, sizeof(tmp), "%s%c", first, last[0]);
			break;
		case 4:  /* JSmith */
			snprintf(tmp, sizeof(tmp), "%c%s", first[0], last);
			break;
		case 5:  /* johnsmith */
			snprintf(tmp, sizeof(tmp), "%s%s", first, last);
			for (char *p = tmp; *p; p++)
				*p = tolower(*p);
			break;
		case 6:  /* Johnny */
			snprintf(tmp, sizeof(tmp), "%sy", first);
			break;
		case 7:  /* John1987 */
			snprintf(tmp, sizeof(tmp), "%s%d", first, 1970 + (getrandom8() % 40));
			break;
		case 8:  /* xJohnx */
			snprintf(tmp, sizeof(tmp), "x%sx", first);
			break;
		case 9:  /* TheJohn */
			snprintf(tmp, sizeof(tmp), "The%s", first);
			break;
		case 10: /* John|UK or similar */
			snprintf(tmp, sizeof(tmp), "%s|%c%c", first,
			         'A' + (getrandom8() % 26), 'A' + (getrandom8() % 26));
			break;
		default: /* First + 3 digits */
			snprintf(tmp, sizeof(tmp), "%s%03d", first, getrandom8() % 1000);
			break;
	}

	/* Ensure it fits and is a valid nick */
	strlcpy(buf, tmp, buflen);
	buf[NICKLEN] = '\0';

	/* Very basic cleanup - replace invalid chars */
	for (char *p = buf; *p; p++)
	{
		if (!isalnum(*p) && *p != '_' && *p != '-' && *p != '|' && *p != '[' && *p != ']')
			*p = '_';
	}
	if (!isalpha(buf[0]) && buf[0] != '_')
		buf[0] = 'A' + (getrandom8() % 26);
}

static void make_realistic_realname(char *buf, size_t buflen)
{
	const char *first = pick(first_names);
	const char *last  = pick(last_names);
	int style = getrandom8() % 6;

	switch (style)
	{
		case 0:
			snprintf(buf, buflen, "%s %s", first, last);
			break;
		case 1:
			snprintf(buf, buflen, "%s %c. %s", first, 'A' + (getrandom8() % 26), last);
			break;
		case 2:
			snprintf(buf, buflen, "%s", first);
			break;
		case 3:
			snprintf(buf, buflen, "%s %s - %s", first, last, pick(ident_bases));
			break;
		case 4:
			snprintf(buf, buflen, "%c. %s", first[0], last);
			break;
		default:
			snprintf(buf, buflen, "%s %s", first, last);
			break;
	}
}

static void make_random_ip(char *buf, size_t buflen)
{
	/* Public IPv4 ranges only (roughly avoid private/reserved) */
	unsigned int a, b, c, d;
	do {
		a = 1 + (getrandom8() % 223);   /* 1-223 */
	} while (a == 10 || a == 127 || (a >= 224));

	b = getrandom8() % 256;
	c = getrandom8() % 256;
	d = 1 + (getrandom8() % 254);

	/* Extra filter for 172.16/12 and 192.168/16 */
	if (a == 172 && b >= 16 && b <= 31)
		b = 32 + (getrandom8() % 200);
	if (a == 192 && b == 168)
		b = 169;

	snprintf(buf, buflen, "%u.%u.%u.%u", a, b, c, d);
}

static void make_ident(char *buf, size_t buflen, const char *nick)
{
	int style = getrandom8() % 5;
	if (style == 0)
	{
		strlcpy(buf, nick, buflen);
		for (char *p = buf; *p; p++)
			*p = tolower(*p);
	}
	else if (style == 1)
		snprintf(buf, buflen, "~%s", pick(ident_bases));
	else if (style == 2)
		strlcpy(buf, pick(ident_bases), buflen);
	else if (style == 3)
		snprintf(buf, buflen, "%s%d", pick(ident_bases), getrandom8() % 100);
	else
	{
		strlcpy(buf, nick, 9);
		for (char *p = buf; *p; p++)
			*p = tolower(*p);
	}
	buf[USERLEN] = '\0';
}

/* ---------- Core: create one fake user ---------- */

static Client *create_one_fake_user(void)
{
	Client *client;
	char nick[NICKLEN + 1];
	char ident[USERLEN + 1];
	char realname[REALLEN + 1];
	char ip[64];
	char host[HOSTLEN + 1];
	int tries = 0;

	/* Find a free nick */
	do {
		make_realistic_nick(nick, sizeof(nick));
		if (++tries > 50)
			return NULL;
	} while (find_client(nick, NULL) != NULL);

	make_realistic_realname(realname, sizeof(realname));
	make_random_ip(ip, sizeof(ip));
	make_ident(ident, sizeof(ident), nick);

	/* Simple reverse-style hostname */
	snprintf(host, sizeof(host), "dynamic-%s.isp.example.net", ip);
	for (char *p = host; *p; p++)
		if (*p == '.')
			; /* keep */
		else if (!isalnum(*p) && *p != '-')
			*p = '-';

	/* Create as a remote client attached to us */
	client = make_client(&me, &me);
	if (!client)
		return NULL;

	/* Basic identity */
	strlcpy(client->name, nick, sizeof(client->name));
	strlcpy(client->ident, ident, sizeof(client->ident));
	strlcpy(client->info, realname, sizeof(client->info));

	/* Make it a full user */
	make_user(client);
	strlcpy(client->user->username, ident, sizeof(client->user->username));
	strlcpy(client->user->realhost, host, sizeof(client->user->realhost));
	strlcpy(client->user->cloakedhost, host, sizeof(client->user->cloakedhost));

	/* Hostname + IP */
	set_sockhost(client, host);
	set_client_ip(client, ip);

	/* Status + flags */
	client->status = CLIENT_STATUS_USER;
	client->umodes = 0;
	client->lastnick = TStime();
	client->direction = &me;
	client->uplink = &me;

	/* UID */
	{
		const char *id;
		while (hash_find_id((id = uid_get()), NULL) != NULL)
			;
		strlcpy(client->id, id, sizeof(client->id));
		add_to_id_hash_table(client->id, client);
	}

	/* Add to global lists / hashes */
	add_client_to_list(client);
	add_to_client_hash_table(client->name, client);

	/* Update global counters so /LUSERS looks correct */
	irccounts.clients++;
	/* Note: we deliberately do NOT increment me_clients because these are remote-style */

	/* Mark as ours */
	mark_fake(client);

	/* Fire remote connect hook so modules / snomasks can see it */
	RunHook(HOOKTYPE_REMOTE_CONNECT, client);

	/* Log similar to normal remote connects (shows up in snomasks / your tracker) */
	unreal_log(ULOG_INFO, "connect", "REMOTE_CLIENT_CONNECT", client,
	           "Client connecting (fake): $client ($client.user.username@$client.hostname) [$client.ip] $client.details",
	           log_data_string("details", client->info));

	return client;
}

/* Randomly join some existing channels */
static void maybe_join_channels(Client *client, int joinchance)
{
	Channel *channel;
	int joined = 0;

	if (joinchance <= 0 || getrandom8() % 100 >= joinchance)
		return;

	/* Walk existing channels and join up to 1-3 of them */
	for (channel = channels; channel; channel = channel->nextch)
	{
		if (IsMember(client, channel))
			continue;
		if (getrandom8() % 100 > 35)
			continue;

		/* Simple join - no key/ban checks for load-test fakes */
		join_channel(channel, client, NULL, "");
		joined++;
		if (joined >= 1 + (getrandom8() % 3))
			break;
	}
}

/* ---------- Batched creation (prevents lag spikes) ---------- */

static void fakeusers_batch(void *arg)
{
	int i;
	int created = 0;

	if (gen_remaining <= 0)
	{
		if (gen_event)
		{
			EventDel(gen_event);
			gen_event = NULL;
		}
		return;
	}

	for (i = 0; i < BATCH_SIZE && gen_remaining > 0; i++)
	{
		Client *acptr = create_one_fake_user();
		if (acptr)
		{
			maybe_join_channels(acptr, gen_joinchance);
			created++;
			gen_remaining--;
		}
		else
		{
			/* nick collision storm or memory - stop */
			gen_remaining = 0;
			break;
		}
	}

	if (gen_remaining <= 0 && gen_event)
	{
		EventDel(gen_event);
		gen_event = NULL;
		sendto_ops(NULL, "FAKEUSERS: finished creating users");
	}
}

/* ---------- Commands ---------- */

CMD_FUNC(cmd_fakeusers)
{
	const char *sub;
	int count, joinchance = 15;
	int current = 0;
	Client *acptr;

	if (!IsOper(client))
	{
		sendnumeric(client, ERR_NOPRIVILEGES);
		return;
	}

	if (parc < 2 || BadPtr(parv[1]))
	{
		sendnotice(client, "Usage: FAKEUSERS <count|CLEAR|STATUS> [joinchance%%]");
		sendnotice(client, "  count       = number of users to create (1-%d)", MAX_FAKEUSERS);
		sendnotice(client, "  joinchance  = %% of users that join random channels (default 15)");
		sendnotice(client, "  CLEAR       = remove all fake users");
		sendnotice(client, "  STATUS      = show how many fake users are online");
		return;
	}

	sub = parv[1];

	if (!strcasecmp(sub, "CLEAR") || !strcasecmp(sub, "QUIT") || !strcasecmp(sub, "PURGE"))
	{
		int removed = 0;
		Client *next;
		list_for_each_entry_safe(acptr, next, &client_list, client_node)
		{
			if (is_fake_client(acptr))
			{
				exit_client(acptr, NULL, "Fake user cleanup");
				removed++;
			}
		}
		sendnotice(client, "FAKEUSERS: removed %d fake users", removed);
		gen_remaining = 0;
		if (gen_event)
		{
			EventDel(gen_event);
			gen_event = NULL;
		}
		return;
	}

	if (!strcasecmp(sub, "STATUS") || !strcasecmp(sub, "COUNT"))
	{
		list_for_each_entry(acptr, &client_list, client_node)
		{
			if (is_fake_client(acptr))
				current++;
		}
		sendnotice(client, "FAKEUSERS: %d fake users currently online (pending creation: %d)",
		           current, gen_remaining);
		return;
	}

	count = atoi(sub);
	if (count < 1 || count > MAX_FAKEUSERS)
	{
		sendnotice(client, "FAKEUSERS: count must be between 1 and %d", MAX_FAKEUSERS);
		return;
	}

	if (parc >= 3 && !BadPtr(parv[2]))
	{
		joinchance = atoi(parv[2]);
		if (joinchance < 0)
			joinchance = 0;
		if (joinchance > 100)
			joinchance = 100;
	}

	/* If a previous generation is still running, cancel it */
	if (gen_event)
	{
		EventDel(gen_event);
		gen_event = NULL;
	}

	gen_remaining = count;
	gen_joinchance = joinchance;

	/* Start batched creation */
	gen_event = EventAdd(modinfo->handle, "fakeusers_batch", fakeusers_batch, NULL, 100, 0);

	sendnotice(client, "FAKEUSERS: starting creation of %d users (joinchance %d%%). This is done in batches to avoid lag.",
	           count, joinchance);
	sendto_ops(NULL, "FAKEUSERS: %s is creating %d fake users for load testing",
	           client->name, count);
}

/* ---------- Module lifecycle ---------- */

static void free_fake_md(ModData *m)
{
	/* nothing dynamic */
}

MOD_INIT()
{
	ModDataInfo mreq;

	MARK_AS_OFFICIAL_MODULE(modinfo);

	memset(&mreq, 0, sizeof(mreq));
	mreq.type = MODDATATYPE_CLIENT;
	mreq.name = "fakeusers";
	mreq.free = free_fake_md;
	md_fake = ModDataAdd(modinfo->handle, mreq);
	if (!md_fake)
	{
		config_error("fakeusers: failed to add moddata");
		return MOD_FAILED;
	}

	CommandAdd(modinfo->handle, "FAKEUSERS", cmd_fakeusers, MAXPARA, CMD_USER | CMD_OPER);

	return MOD_SUCCESS;
}

MOD_LOAD()
{
	return MOD_SUCCESS;
}

MOD_UNLOAD()
{
	/* Best effort cleanup */
	Client *acptr, *next;
	list_for_each_entry_safe(acptr, next, &client_list, client_node)
	{
		if (is_fake_client(acptr))
			exit_client(acptr, NULL, "Module unloaded");
	}
	return MOD_SUCCESS;
}
