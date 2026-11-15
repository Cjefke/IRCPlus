// Anope IRC Services <https://www.anope.org/>
//
// m_youtube - YouTube link information module
// Detects YouTube links in channels and replies with video info
// using the YouTube Data API v3.
//
// Requires: libcurl
//
// Configuration example (in modules.conf or anope.conf):
//
// module
// {
//     name = "m_youtube"
//
//     // Your YouTube Data API v3 key (required)
//     api_key = "YOUR_API_KEY_HERE"
//
//     // Comma-separated list of channels where the module is active.
//     // Use "*" for all channels.
//     channels = "#IRCPlus,#Holland,#test"
//
//     // Cache time in seconds (default 300 = 5 minutes)
//     cache_time = 300
//
//     // Maximum title length before truncation
//     max_title_length = 80
//
//     // Show the notice via the channel BotServ bot if available?
//     // (otherwise services itself speaks)
//     use_bot = yes
// }
//
// SPDX-License-Identifier: GPL-2.0-only

/// BEGIN CMAKE
/// find_package(CURL REQUIRED)
/// target_link_libraries(${SO} PRIVATE CURL::libcurl vendored_yyjson)
/// END CMAKE

#include "module.h"
#include "modules/botserv/bot.h"

#include <curl/curl.h>
#include "yyjson/yyjson.h"

#include <regex>
#include <map>
#include <mutex>

class YouTubeCacheEntry
{
public:
	Anope::string title;
	Anope::string uploader;
	Anope::string duration;
	Anope::string views;
	Anope::string published;
	time_t expires = 0;
};

class ModuleYouTube final
	: public Module
{
	Anope::string api_key;
	std::set<Anope::string> enabled_channels; // lowercase
	bool all_channels = false;
	time_t cache_time = 300;
	size_t max_title_length = 80;
	bool use_bot = true;

	std::map<Anope::string, YouTubeCacheEntry> cache;
	std::mutex cache_mutex;

	// Simple regex for video IDs (11 chars)
	std::regex yt_regex{
		R"((?:youtube\.com/(?:watch\?[^\s]*v=|shorts/)|youtu\.be/)([A-Za-z0-9_-]{11}))",
		std::regex::icase
	};

	static size_t CurlWriteCallback(void *contents, size_t size, size_t nmemb, void *userp)
	{
		((Anope::string *)userp)->append(static_cast<char *>(contents), size * nmemb);
		return size * nmemb;
	}

	bool IsChannelEnabled(Channel *c) const
	{
		if (!c)
			return false;
		if (all_channels)
			return true;
		return enabled_channels.count(c->name.lower()) > 0;
	}

	Anope::string FormatDuration(const Anope::string &iso)
	{
		// ISO 8601: PT#H#M#S
		unsigned hours = 0, minutes = 0, seconds = 0;
		std::smatch m;
		std::string s = iso.str();

		if (std::regex_search(s, m, std::regex(R"((\d+)H)")))
			hours = std::stoul(m[1]);
		if (std::regex_search(s, m, std::regex(R"((\d+)M)")))
			minutes = std::stoul(m[1]);
		if (std::regex_search(s, m, std::regex(R"((\d+)S)")))
			seconds = std::stoul(m[1]);

		char buf[32];
		if (hours > 0)
			snprintf(buf, sizeof(buf), "%u:%02u:%02u", hours, minutes, seconds);
		else
			snprintf(buf, sizeof(buf), "%u:%02u", minutes, seconds);
		return buf;
	}

	bool FetchVideoInfo(const Anope::string &video_id, YouTubeCacheEntry &out)
	{
		if (api_key.empty())
			return false;

		Anope::string url = "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics"
			"&id=" + video_id + "&key=" + api_key;

		CURL *curl = curl_easy_init();
		if (!curl)
			return false;

		Anope::string response;
		curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CurlWriteCallback);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
		curl_easy_setopt(curl, CURLOPT_TIMEOUT, 8L);
		curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
		curl_easy_setopt(curl, CURLOPT_USERAGENT, "Anope-m_youtube/1.0");
		curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

		CURLcode res = curl_easy_perform(curl);
		long http_code = 0;
		curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
		curl_easy_cleanup(curl);

		if (res != CURLE_OK || http_code != 200 || response.empty())
		{
			Log(LOG_DEBUG) << "m_youtube: HTTP request failed for " << video_id
				<< " (curl=" << res << " http=" << http_code << ")";
			return false;
		}

		yyjson_doc *doc = yyjson_read(response.c_str(), response.length(), 0);
		if (!doc)
			return false;

		yyjson_val *root = yyjson_doc_get_root(doc);
		yyjson_val *items = yyjson_obj_get(root, "items");
		if (!items || !yyjson_is_arr(items) || yyjson_arr_size(items) == 0)
		{
			yyjson_doc_free(doc);
			return false;
		}

		yyjson_val *item = yyjson_arr_get(items, 0);
		yyjson_val *snippet = yyjson_obj_get(item, "snippet");
		yyjson_val *content = yyjson_obj_get(item, "contentDetails");
		yyjson_val *stats = yyjson_obj_get(item, "statistics");

		if (snippet)
		{
			yyjson_val *v = yyjson_obj_get(snippet, "title");
			if (v && yyjson_is_str(v))
				out.title = yyjson_get_str(v);

			v = yyjson_obj_get(snippet, "channelTitle");
			if (v && yyjson_is_str(v))
				out.uploader = yyjson_get_str(v);

			v = yyjson_obj_get(snippet, "publishedAt");
			if (v && yyjson_is_str(v))
			{
				Anope::string pub = yyjson_get_str(v);
				// Take only YYYY-MM-DD
				if (pub.length() >= 10)
					out.published = pub.substr(0, 10);
			}
		}

		if (content)
		{
			yyjson_val *v = yyjson_obj_get(content, "duration");
			if (v && yyjson_is_str(v))
				out.duration = FormatDuration(yyjson_get_str(v));
		}

		if (stats)
		{
			yyjson_val *v = yyjson_obj_get(stats, "viewCount");
			if (v && yyjson_is_str(v))
				out.views = yyjson_get_str(v);
		}

		yyjson_doc_free(doc);

		if (out.title.empty())
			out.title = "Unknown title";
		if (out.uploader.empty())
			out.uploader = "Unknown";
		if (out.duration.empty())
			out.duration = "?:??";
		if (out.views.empty())
			out.views = "?";
		if (out.published.empty())
			out.published = "?";

		out.expires = Anope::CurTime + cache_time;
		return true;
	}

	void SendReply(Channel *c, const Anope::string &line)
	{
		if (!c)
			return;

		if (use_bot && c->ci && c->ci->bi)
		{
			ircdproto->SendPrivmsg(c->ci->bi, c->name, "%s", line.c_str());
		}
		else
		{
			// Fallback: services itself (or the first available bot)
			ServiceBot *bot = Config->GetClient("BotServ");
			if (!bot)
				bot = Config->GetClient("ChanServ");
			if (bot)
				ircdproto->SendPrivmsg(bot, c->name, "%s", line.c_str());
		}
	}

public:
	ModuleYouTube(const Anope::string &modname, const Anope::string &creator)
		: Module(modname, creator, THIRD)
	{
		this->SetAuthor("Grok / community");
		this->SetVersion("1.0");

		curl_global_init(CURL_GLOBAL_DEFAULT);
	}

	~ModuleYouTube() override
	{
		curl_global_cleanup();
	}

	void OnReload(Configuration::Conf &conf) override
	{
		const auto &block = conf.GetModule(this);

		api_key = block.Get<const Anope::string>("api_key", "");
		cache_time = block.Get<time_t>("cache_time", 300);
		max_title_length = block.Get<size_t>("max_title_length", 80);
		use_bot = block.Get<bool>("use_bot", true);

		enabled_channels.clear();
		all_channels = false;

		Anope::string chans = block.Get<const Anope::string>("channels", "*");
		if (chans == "*" || chans.equals_ci("all"))
		{
			all_channels = true;
		}
		else
		{
			commasepstream sep(chans);
			Anope::string tok;
			while (sep.GetToken(tok))
			{
				tok = tok.lower().trim();
				if (!tok.empty())
					enabled_channels.insert(tok);
			}
		}

		if (api_key.empty())
			Log(LOG_NORMAL) << "m_youtube: WARNING - no api_key configured, module will do nothing";
		else
			Log(LOG_NORMAL) << "m_youtube: loaded (channels="
				<< (all_channels ? "*" : Anope::ToString(enabled_channels.size()))
				<< ", cache=" << cache_time << "s)";
	}

	void OnPrivmsg(User *u, Channel *c, Anope::string &msg, const Anope::map<Anope::string> &tags) override
	{
		if (!u || !c || msg.empty() || api_key.empty())
			return;

		if (!IsChannelEnabled(c))
			return;

		// Ignore CTCP / actions
		if (msg[0] == '\1')
			return;

		std::smatch match;
		std::string text = msg.str();
		if (!std::regex_search(text, match, yt_regex))
			return;

		Anope::string video_id = match[1].str();
		if (video_id.length() != 11)
			return;

		YouTubeCacheEntry entry;
		bool found = false;

		{
			std::lock_guard<std::mutex> lock(cache_mutex);
			auto it = cache.find(video_id);
			if (it != cache.end() && it->second.expires > Anope::CurTime)
			{
				entry = it->second;
				found = true;
			}
		}

		if (!found)
		{
			if (!FetchVideoInfo(video_id, entry))
			{
				Log(LOG_DEBUG) << "m_youtube: failed to fetch info for " << video_id;
				return;
			}

			std::lock_guard<std::mutex> lock(cache_mutex);
			cache[video_id] = entry;

			// Simple cache cleanup: remove expired entries occasionally
			if (cache.size() > 200)
			{
				for (auto it = cache.begin(); it != cache.end(); )
				{
					if (it->second.expires <= Anope::CurTime)
						it = cache.erase(it);
					else
						++it;
				}
			}
		}

		Anope::string title = entry.title;
		if (title.length() > max_title_length)
			title = title.substr(0, max_title_length - 3) + "...";

		Anope::string uploader = entry.uploader;
		if (uploader.length() > 35)
			uploader = uploader.substr(0, 32) + "...";

		// Compact one-liner (same style as the original mIRC script)
		Anope::string line = Anope::printf(
			"[YouTube] \u25B6 %s | Length: %s | By: %s | Views: %s | Published: %s",
			title.c_str(),
			entry.duration.c_str(),
			uploader.c_str(),
			entry.views.c_str(),
			entry.published.c_str()
		);

		SendReply(c, line);
	}
};

MODULE_INIT(ModuleYouTube)
