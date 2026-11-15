/*
 * fakeusers - Load-test module for UnrealIRCd 6 (safe rewrite)
 */
#include "unrealircd.h"

#define MAX_FAKEUSERS 25000
#define BATCH_SIZE 25

ModuleHeader MOD_HEADER = {
	"third/fakeusers",
	"1.1.0",
	"Create realistic fake users for load testing",
	"IRCPlus",
	"unrealircd-6",
};

static Module *fakeusers_module = NULL;
static ModDataInfo *md_fake = NULL;
static int gen_remaining = 0;
static int gen_joinchance = 0;
static Event *gen_event = NULL;

static const char *first_names[] = {
	"James","John","Robert","Michael","William","David","Richard","Joseph","Thomas","Charles",
	"Christopher","Daniel","Matthew","Anthony","Mark","Donald","Steven","Paul","Andrew","Joshua",
	"Kevin","Brian","George","Timothy","Edward","Jason","Ryan","Jacob","Gary","Nicholas",
	"Eric","Jonathan","Justin","Scott","Brandon","Benjamin","Samuel","Frank","Patrick","Jack",
	"Tyler","Aaron","Adam","Nathan","Henry","Peter","Kyle","Noah","Ethan","Jeremy",
	"Mary","Patricia","Jennifer","Linda","Elizabeth","Barbara","Susan","Jessica","Sarah","Karen",
	"Nancy","Lisa","Betty","Margaret","Sandra","Ashley","Kimberly","Emily","Donna","Michelle",
	"Carol","Amanda","Melissa","Deborah","Stephanie","Rebecca","Sharon","Laura","Cynthia","Amy",
	"Angela","Anna","Brenda","Emma","Nicole","Helen","Samantha","Katherine","Rachel","Catherine",
	"Maria","Heather","Diane","Ruth","Julie","Olivia","Joyce","Virginia","Victoria","Kelly",
	NULL
};

static const char *last_names[] = {
	"Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez",
	"Hernandez","Lopez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin","Lee",
	"Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson","Walker",
	"Young","Allen","King","Wright","Scott","Torres","Hill","Flores","Green","Adams",
	"Nelson","Baker","Hall","Rivera","Campbell","Mitchell","Carter","Roberts","Gomez","Phillips",
	NULL
};

static int is_fake_client(Client *client)
{
	if (!client || !IsUser(client) || !md_fake)
		return 0;
	return moddata_client(client, md_fake).i ? 1 : 0;
}

static void mark_fake(Client *client)
{
	if (md_fake)
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

static void make_nick(char *buf, size_t buflen)
{
	const char *first = pick(first_names);
	int style = getrandom8() % 6;
	char tmp[64];

	switch (style)
	{
		case 0: snprintf(tmp, sizeof(tmp), "%s", first); break;
		case 1: snprintf(tmp, sizeof(tmp), "%s%d", first, 1 + (getrandom8() % 99)); break;
		case 2: snprintf(tmp, sizeof(tmp), "%s_%d", first, getrandom8() % 1000); break;
		case 3: snprintf(tmp, sizeof(tmp), "%s%d", first, 1980 + (getrandom8() % 30)); break;
		case 4: snprintf(tmp, sizeof(tmp), "x%s", first); break;
		default: snprintf(tmp, sizeof(tmp), "%s%d", first, getrandom8() % 100); break;
	}
	strlcpy(buf, tmp, buflen);
	if (!isalpha((unsigned char)buf[0]))
		buf[0] = 'A';
}

static void make_realname(char *buf, size_t buflen)
{
	snprintf(buf, buflen, "%s %s", pick(first_names), pick(last_names));
}

static void make_ip(char *buf, size_t buflen)
{
	unsigned int a, b, c, d;
	do { a = 1 + (getrandom8() % 223); } while (a == 10 || a == 127 || a >= 224);
	b = getrandom8() % 256;
	c = getrandom8() % 256;
	d = 1 + (getrandom8() % 254);
	if (a == 172 && b >= 16 && b <= 31) b = 40;
	if (a == 192 && b == 168) b = 100;
	snprintf(buf, buflen, "%u.%u.%u.%u", a, b, c, d);
}

static Client *create_one_fake_user(void)
{
	Client *client;
	char nick[NICKLEN + 1];
	char ident[USERLEN + 1];
	char realname[REALLEN + 1];
	char ipstr[64];
	char host[HOSTLEN + 1];
	const char *id;
	int tries = 0;

	do {
		make_nick(nick, sizeof(nick));
		if (++tries > 40)
			return NULL;
	} while (find_client(nick, NULL));

	make_realname(realname, sizeof(realname));
	make_ip(ipstr, sizeof(ipstr));
	strlcpy(ident, "user", sizeof(ident));
	snprintf(host, sizeof(host), "dyn-%s.example.net", ipstr);

	client = make_client(&me, &me);
	if (!client)
		return NULL;

	strlcpy(client->name, nick, sizeof(client->name));
	strlcpy(client->ident, ident, sizeof(client->ident));
	strlcpy(client->info, realname, sizeof(client->info));

	make_user(client);
	if (!client->user)
	{
		free_client(client);
		return NULL;
	}

	strlcpy(client->user->username, ident, sizeof(client->user->username));
	strlcpy(client->user->realhost, host, sizeof(client->user->realhost));
	strlcpy(client->user->cloakedhost, host, sizeof(client->user->cloakedhost));
	safe_strdup(client->user->virthost, host);

	/* IP without set_client_ip / set_sockhost */
	safe_strdup(client->ip, ipstr);
	memset(client->rawip, 0, sizeof(client->rawip));
	inet_pton(AF_INET, ipstr, client->rawip);

	client->status = CLIENT_STATUS_USER;
	client->umodes = 0;
	client->lastnick = TStime();
	client->direction = &me;
	client->uplink = &me;

	while (hash_find_id((id = uid_get()), NULL))
		;
	strlcpy(client->id, id, sizeof(client->id));
	add_to_id_hash_table(client->id, client);

	add_client_to_list(client);
	add_to_client_hash_table(client->name, client);

	irccounts.clients++;
	mark_fake(client);

	return client;
}

static void fakeusers_batch(void *arg)
{
	int i;

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
		if (!acptr)
		{
			gen_remaining = 0;
			break;
		}
		gen_remaining--;
	}

	if (gen_remaining <= 0 && gen_event)
	{
		EventDel(gen_event);
		gen_event = NULL;
	}
}

CMD_FUNC(cmd_fakeusers)
{
	const char *sub;
	int count;
	int current = 0;
	Client *acptr;

	if (!IsOper(client))
	{
		sendnumeric(client, ERR_NOPRIVILEGES);
		return;
	}

	if (parc < 2 || BadPtr(parv[1]))
	{
		sendnotice(client, "Usage: FAKEUSERS <count|CLEAR|STATUS>");
		return;
	}

	sub = parv[1];

	if (!strcasecmp(sub, "CLEAR") || !strcasecmp(sub, "QUIT"))
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

	if (!strcasecmp(sub, "STATUS"))
	{
		list_for_each_entry(acptr, &client_list, client_node)
		{
			if (is_fake_client(acptr))
				current++;
		}
		sendnotice(client, "FAKEUSERS: %d online, %d pending", current, gen_remaining);
		return;
	}

	count = atoi(sub);
	if (count < 1 || count > MAX_FAKEUSERS)
	{
		sendnotice(client, "FAKEUSERS: count must be 1-%d", MAX_FAKEUSERS);
		return;
	}

	if (gen_event)
	{
		EventDel(gen_event);
		gen_event = NULL;
	}

	gen_remaining = count;
	gen_joinchance = 0;
	gen_event = EventAdd(fakeusers_module, "fakeusers_batch", fakeusers_batch, NULL, 150, 0);

	sendnotice(client, "FAKEUSERS: creating %d users in batches...", count);
}

static void free_fake_md(ModData *m)
{
}

MOD_INIT()
{
	ModDataInfo mreq;

	fakeusers_module = modinfo->handle;
	MARK_AS_OFFICIAL_MODULE(modinfo);

	memset(&mreq, 0, sizeof(mreq));
	mreq.type = MODDATATYPE_CLIENT;
	mreq.name = "fakeusers";
	mreq.free = free_fake_md;
	md_fake = ModDataAdd(modinfo->handle, mreq);
	if (!md_fake)
	{
		config_error("fakeusers: ModDataAdd failed");
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
	Client *acptr, *next;
	list_for_each_entry_safe(acptr, next, &client_list, client_node)
	{
		if (is_fake_client(acptr))
			exit_client(acptr, NULL, "Module unloaded");
	}
	return MOD_SUCCESS;
}
