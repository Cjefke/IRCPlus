// Anope IRC Services <https://www.anope.org/>
//
// m_weather - Weather information module (weatherapi.com)
// Based on the mIRC Weather v2.2 script by entropy
//
// Requires: libcurl
//
// Commands:
//   !w [location]     - Show current weather (+ today forecast)
//   !wset <location>  - Set your personal default location
//
// Configuration example:
//
// module
// {
//     name = "m_weather"
//
//     // Your weatherapi.com API key (required)
//     // Get one free at: https://www.weatherapi.com/signup.aspx
//     api_key = "YOUR_API_KEY_HERE"
//
//     // Channels where the module is active (* = all)
//     channels = "#chat,#weer,#holland"
//
//     // Command prefix
//     prefix = "!"
//
//     // Use BotServ bot of the channel to speak?
//     use_bot = yes
//
//     // Cache time in seconds (default 600 = 10 minutes)
//     cache_time = 600
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

#include <map>
#include <mutex>

class WeatherCacheEntry
{
public:
	Anope::string line1;
	Anope::string line2;
	time_t expires = 0;
};

class ModuleWeather final
	: public Module
{
	Anope::string api_key;
	std::set<Anope::string> enabled_channels;
	bool all_channels = false;
	Anope::string prefix = "!";
	bool use_bot = true;
	time_t cache_time = 600;

	// nick (lowercase) -> default location
	std::map<Anope::string, Anope::string> defaults;
	// location (lowercase) -> cached result
	std::map<Anope::string, WeatherCacheEntry> cache;
	std::mutex state_mutex;

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

	void SendReply(Channel *c, const Anope::string &line)
	{
		if (!c)
			return;

		ServiceBot *bot = nullptr;
		if (use_bot && c->ci && c->ci->bi)
			bot = c->ci->bi;
		if (!bot)
			bot = Config->GetClient("BotServ");
		if (!bot)
			bot = Config->GetClient("ChanServ");

		if (bot)
			ircdproto->SendPrivmsg(bot, c->name, "%s", line.c_str());
	}

	Anope::string UrlEncode(const Anope::string &in)
	{
		Anope::string out;
		static const char *hex = "0123456789ABCDEF";
		for (unsigned char c : in)
		{
			if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~')
				out += c;
			else if (c == ' ')
				out += '+';
			else
			{
				out += '%';
				out += hex[c >> 4];
				out += hex[c & 0x0F];
			}
		}
		return out;
	}

	Anope::string ConditionEmoji(const Anope::string &text)
	{
		Anope::string t = text;
		// Simple replacements matching the original script style
		if (t.find_ci("sunny") != Anope::string::npos) return "🌞 " + t;
		if (t.find_ci("clear") != Anope::string::npos) return "🌙 " + t;
		if (t.find_ci("partly cloudy") != Anope::string::npos) return "⛅ " + t;
		if (t.find_ci("cloudy") != Anope::string::npos) return "☁️ " + t;
		if (t.find_ci("overcast") != Anope::string::npos) return "🌥️ " + t;
		if (t.find_ci("patchy rain") != Anope::string::npos || t.find_ci("light rain") != Anope::string::npos)
			return "🌦️ " + t;
		if (t.find_ci("moderate rain") != Anope::string::npos) return "🌧️ " + t;
		if (t.find_ci("heavy rain") != Anope::string::npos) return "🌧️🔥 " + t;
		if (t.find_ci("snow") != Anope::string::npos) return "❄️ " + t;
		if (t.find_ci("mist") != Anope::string::npos || t.find_ci("fog") != Anope::string::npos)
			return "🌫️ " + t;
		return t;
	}

	Anope::string GetStr(yyjson_val *obj, const char *key)
	{
		if (!obj)
			return "";
		yyjson_val *v = yyjson_obj_get(obj, key);
		if (v && yyjson_is_str(v))
			return yyjson_get_str(v);
		return "";
	}

	double GetNum(yyjson_val *obj, const char *key)
	{
		if (!obj)
			return 0.0;
		yyjson_val *v = yyjson_obj_get(obj, key);
		if (v && yyjson_is_num(v))
			return yyjson_get_num(v);
		return 0.0;
	}

	bool FetchWeather(const Anope::string &location, WeatherCacheEntry &out)
	{
		if (api_key.empty())
			return false;

		Anope::string url = "https://api.weatherapi.com/v1/forecast.json?key=" + api_key
			+ "&q=" + UrlEncode(location)
			+ "&days=1&aqi=no&alerts=no";

		CURL *curl = curl_easy_init();
		if (!curl)
			return false;

		Anope::string response;
		curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CurlWriteCallback);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
		curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
		curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
		curl_easy_setopt(curl, CURLOPT_USERAGENT, "Anope-m_weather/1.0");
		curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

		CURLcode res = curl_easy_perform(curl);
		long http_code = 0;
		curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
		curl_easy_cleanup(curl);

		if (res != CURLE_OK || http_code != 200 || response.empty())
		{
			Log(LOG_DEBUG) << "m_weather: request failed for '" << location
				<< "' (curl=" << res << " http=" << http_code << ")";
			return false;
		}

		yyjson_doc *doc = yyjson_read(response.c_str(), response.length(), 0);
		if (!doc)
			return false;

		yyjson_val *root = yyjson_doc_get_root(doc);
		yyjson_val *loc = yyjson_obj_get(root, "location");
		yyjson_val *cur = yyjson_obj_get(root, "current");
		yyjson_val *forecast = yyjson_obj_get(root, "forecast");
		yyjson_val *forecastday = nullptr;
		yyjson_val *day = nullptr;
		yyjson_val *astro = nullptr;

		if (forecast)
		{
			yyjson_val *fdays = yyjson_obj_get(forecast, "forecastday");
			if (fdays && yyjson_is_arr(fdays) && yyjson_arr_size(fdays) > 0)
			{
				forecastday = yyjson_arr_get(fdays, 0);
				if (forecastday)
				{
					day = yyjson_obj_get(forecastday, "day");
					astro = yyjson_obj_get(forecastday, "astro");
				}
			}
		}

		// Location
		Anope::string city = GetStr(loc, "name");
		Anope::string region = GetStr(loc, "region");
		Anope::string country = GetStr(loc, "country");
		if (country.equals_ci("United States of America"))
			country = "US";

		Anope::string place = city;
		if (!region.empty())
			place += ", " + region;
		if (!country.empty())
			place += ", " + country;

		// Current
		double temp_c = GetNum(cur, "temp_c");
		double feels_c = GetNum(cur, "feelslike_c");
		Anope::string wind_dir = GetStr(cur, "wind_dir");
		double wind_kph = GetNum(cur, "wind_kph");
		double gust_kph = GetNum(cur, "gust_kph");
		int humidity = static_cast<int>(GetNum(cur, "humidity"));
		double uv = GetNum(cur, "uv");
		Anope::string last_updated = GetStr(cur, "last_updated");

		yyjson_val *cond = yyjson_obj_get(cur, "condition");
		Anope::string condition = GetStr(cond, "text");
		condition = ConditionEmoji(condition);

		// Day forecast
		double mintemp = GetNum(day, "mintemp_c");
		double maxtemp = GetNum(day, "maxtemp_c");
		int chance_rain = static_cast<int>(GetNum(day, "daily_chance_of_rain"));

		// Astro
		Anope::string sunrise = GetStr(astro, "sunrise");
		Anope::string sunset = GetStr(astro, "sunset");

		// Build two lines (same style as original)
		// Line 1: location + temps + wind + humidity
		Anope::string line1 = Anope::printf(
			"[Weather] ● %s ● Temperature: %.1f°C",
			place.c_str(), temp_c);

		if (std::abs(temp_c - feels_c) > 0.4)
			line1 += Anope::printf(" ● Feels like: %.1f°C", feels_c);

		line1 += Anope::printf(" ● 💨 Wind: %s %.0f km/h ● 💧 Humidity: %d%%",
			wind_dir.c_str(), wind_kph, humidity);

		// Line 2: min/max, gust, rain, UV, sun, condition, update
		Anope::string line2 = Anope::printf(
			"[Weather] ● ⬇️ MinTemp: %.1f°C ● ⬆️ MaxTemp: %.1f°C ● 💥 Max Wind: %.0f km/h ● ☔ Chance of rain: %d%% ● ☀️ UV %.1f",
			mintemp, maxtemp, gust_kph, chance_rain, uv);

		if (!sunrise.empty())
			line2 += " ● 🌅 Sunrise: " + sunrise;
		if (!sunset.empty())
			line2 += " ● 🌇 Sunset: " + sunset;

		line2 += " ● " + condition;

		if (!last_updated.empty())
		{
			// Prefer just the time part if present
			size_t sp = last_updated.find(' ');
			if (sp != Anope::string::npos)
				line2 += " ● 🕒 Last update: " + last_updated.substr(sp + 1);
			else
				line2 += " ● 🕒 Last update: " + last_updated;
		}

		out.line1 = line1;
		out.line2 = line2;
		out.expires = Anope::CurTime + cache_time;

		yyjson_doc_free(doc);
		return true;
	}

	void ShowWeather(Channel *c, User *u, const Anope::string &location)
	{
		if (location.empty())
		{
			SendReply(c, "You have not set a default location yet. Use: " + prefix + "wset <location>");
			return;
		}

		Anope::string key = location.lower();
		WeatherCacheEntry entry;
		bool found = false;

		{
			std::lock_guard<std::mutex> lock(state_mutex);
			auto it = cache.find(key);
			if (it != cache.end() && it->second.expires > Anope::CurTime)
			{
				entry = it->second;
				found = true;
			}
		}

		if (!found)
		{
			if (!FetchWeather(location, entry))
			{
				SendReply(c, "[Weather] ● Could not fetch weather for \"" + location + "\". Check the location or API key.");
				return;
			}

			std::lock_guard<std::mutex> lock(state_mutex);
			cache[key] = entry;

			// Simple cleanup
			if (cache.size() > 150)
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

		SendReply(c, entry.line1);
		SendReply(c, entry.line2);
	}

public:
	ModuleWeather(const Anope::string &modname, const Anope::string &creator)
		: Module(modname, creator, THIRD)
	{
		this->SetAuthor("Grok / community");
		this->SetVersion("1.0");
		curl_global_init(CURL_GLOBAL_DEFAULT);
	}

	~ModuleWeather() override
	{
		curl_global_cleanup();
	}

	void OnReload(Configuration::Conf &conf) override
	{
		const auto &block = conf.GetModule(this);

		api_key = block.Get<const Anope::string>("api_key", "");
		prefix = block.Get<const Anope::string>("prefix", "!");
		use_bot = block.Get<bool>("use_bot", true);
		cache_time = block.Get<time_t>("cache_time", 600);

		enabled_channels.clear();
		all_channels = false;
		Anope::string chans = block.Get<const Anope::string>("channels", "*");
		if (chans == "*" || chans.equals_ci("all"))
			all_channels = true;
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
			Log(LOG_NORMAL) << "m_weather: WARNING - no api_key configured";
		else
			Log(LOG_NORMAL) << "m_weather: loaded (channels="
				<< (all_channels ? "*" : Anope::ToString(enabled_channels.size()))
				<< ", cache=" << cache_time << "s)";
	}

	void OnPrivmsg(User *u, Channel *c, Anope::string &msg, const Anope::map<Anope::string> &tags) override
	{
		if (!u || !c || msg.empty() || msg[0] == '\1')
			return;
		if (!IsChannelEnabled(c))
			return;
		if (api_key.empty())
			return;

		Anope::string text = msg;
		text.trim();

		if (text.length() < prefix.length() || text.substr(0, prefix.length()) != prefix)
			return;

		Anope::string cmdline = text.substr(prefix.length());
		cmdline.trim();
		if (cmdline.empty())
			return;

		spacesepstream sep(cmdline);
		Anope::string cmd;
		if (!sep.GetToken(cmd))
			return;
		cmd = cmd.lower();

		Anope::string args;
		sep.GetRemaining(args);
		args.trim();

		if (cmd == "wset")
		{
			if (args.empty())
			{
				SendReply(c, "Usage: " + prefix + "wset <location>");
				return;
			}

			{
				std::lock_guard<std::mutex> lock(state_mutex);
				defaults[u->nick.lower()] = args;
			}

			SendReply(c, "Your default weather location is now: " + args);
			return;
		}

		if (cmd == "w" || cmd == "weather")
		{
			Anope::string location = args;

			if (location.empty())
			{
				std::lock_guard<std::mutex> lock(state_mutex);
				auto it = defaults.find(u->nick.lower());
				if (it != defaults.end())
					location = it->second;
			}

			ShowWeather(c, u, location);
		}
	}
};

MODULE_INIT(ModuleWeather)
