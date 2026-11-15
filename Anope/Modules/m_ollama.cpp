// Anope IRC Services <https://www.anope.org/>
//
// m_ollama - Local AI (Ollama) integration module
// Provides !gpt commands that talk to a local Ollama instance.
//
// Requires: libcurl
//
// Configuration example:
//
// module
// {
//     name = "m_ollama"
//
//     // Ollama connection
//     host = "127.0.0.1"
//     port = 11434
//
//     // Default model
//     model = "phi4-mini"
//
//     // Optional system prompt (empty = model default)
//     system_prompt = ""
//
//     // Channels where the module is active (* = all)
//     channels = "#services,#chat,#AI"
//
//     // Rate limiting
//     query_limit = 5          // max queries
//     query_window = 60        // per seconds
//
//     // Conversation memory
//     max_context = 5          // previous exchanges to remember per channel
//
//     // Response limits
//     max_response_length = 400
//     timeout = 90             // HTTP timeout in seconds
//
//     // Use BotServ bot of the channel to speak?
//     use_bot = yes
//
//     // Command prefix (default !)
//     prefix = "!"
// }
//
// Commands (in enabled channels):
//   !gpt <vraag>           - Stel een vraag aan de AI
//   !gpt-status            - Check of Ollama bereikbaar is
//   !gpt-models            - Lijst beschikbare modellen
//   !gpt-model [naam]      - Toon of wijzig het huidige model
//   !gpt-system [prompt]   - Toon/zet/clear system prompt
//   !gpt-clear             - Wis conversatie-geschiedenis van dit kanaal
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
#include <deque>
#include <mutex>
#include <vector>
#include <algorithm>

class ModuleOllama final
	: public Module
{
	// Config
	Anope::string host = "127.0.0.1";
	int port = 11434;
	Anope::string model = "phi4-mini";
	Anope::string system_prompt;
	std::set<Anope::string> enabled_channels;
	bool all_channels = false;
	unsigned query_limit = 5;
	time_t query_window = 60;
	unsigned max_context = 5;
	size_t max_response_length = 400;
	long timeout = 90;
	bool use_bot = true;
	Anope::string prefix = "!";

	// Runtime state
	std::map<Anope::string, std::deque<time_t>> rate_tracker;          // "chan:nick" -> timestamps
	std::map<Anope::string, std::deque<std::pair<Anope::string, Anope::string>>> history; // chan -> {user, assistant}
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

	Anope::string CleanIRC(const Anope::string &in)
	{
		Anope::string out;
		for (size_t i = 0; i < in.length(); ++i)
		{
			unsigned char c = in[i];
			if (c == 0x03) // color
			{
				++i;
				while (i < in.length() && (isdigit(in[i]) || in[i] == ','))
					++i;
				--i;
				continue;
			}
			if (c == 0x02 || c == 0x0F || c == 0x16 || c == 0x1F || c == 0x1D || c == 0x19)
				continue;
			out += c;
		}
		return out;
	}

	void SendReply(Channel *c, User *u, const Anope::string &text)
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

		if (!bot)
			return;

		// Split long responses
		Anope::string remaining = text;
		unsigned part = 1;
		bool multi = remaining.length() > max_response_length;

		while (!remaining.empty())
		{
			Anope::string chunk;
			if (remaining.length() <= max_response_length)
			{
				chunk = remaining;
				remaining.clear();
			}
			else
			{
				// Prefer break on space
				size_t pos = remaining.rfind(' ', max_response_length);
				if (pos == Anope::string::npos || pos < max_response_length / 2)
					pos = max_response_length;
				chunk = remaining.substr(0, pos);
				remaining = remaining.substr(pos);
				remaining.trim();
			}

			Anope::string line;
			if (multi)
				line = Anope::printf("\002%s\002 (%u): %s", u->nick.c_str(), part++, chunk.c_str());
			else
				line = Anope::printf("\002%s\002: %s", u->nick.c_str(), chunk.c_str());

			ircdproto->SendPrivmsg(bot, c->name, "%s", line.c_str());
		}
	}

	bool CheckRateLimit(const Anope::string &key, Anope::string &wait_msg)
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		time_t now = Anope::CurTime;

		auto &times = rate_tracker[key];
		// Remove old entries
		while (!times.empty() && (now - times.front()) >= query_window)
			times.pop_front();

		if (times.size() >= query_limit)
		{
			time_t wait = query_window - (now - times.front());
			wait_msg = Anope::printf("Rate limit exceeded. Please wait %ld seconds.", static_cast<long>(wait));
			return false;
		}

		times.push_back(now);
		return true;
	}

	Anope::string BuildPrompt(const Anope::string &chan, const Anope::string &query)
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		auto it = history.find(chan);
		if (it == history.end() || it->second.empty())
			return query;

		Anope::string prompt = "Previous conversation:\n";
		for (const auto &ex : it->second)
		{
			prompt += "User: " + ex.first + "\nAssistant: " + ex.second + "\n";
		}
		prompt += "\nCurrent question: " + query;
		return prompt;
	}

	void StoreExchange(const Anope::string &chan, const Anope::string &user_msg, const Anope::string &assistant_msg)
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		auto &hist = history[chan];
		hist.emplace_back(user_msg, assistant_msg);
		while (hist.size() > max_context)
			hist.pop_front();
	}

	void ClearHistory(const Anope::string &chan)
	{
		std::lock_guard<std::mutex> lock(state_mutex);
		history.erase(chan);
	}

	bool HttpRequest(const Anope::string &url, const Anope::string &post_data, Anope::string &response, long &http_code)
	{
		CURL *curl = curl_easy_init();
		if (!curl)
			return false;

		response.clear();
		curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CurlWriteCallback);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
		curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
		curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
		curl_easy_setopt(curl, CURLOPT_USERAGENT, "Anope-m_ollama/1.0");

		struct curl_slist *headers = nullptr;
		if (!post_data.empty())
		{
			headers = curl_slist_append(headers, "Content-Type: application/json");
			curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
			curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_data.c_str());
		}

		CURLcode res = curl_easy_perform(curl);
		http_code = 0;
		curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

		if (headers)
			curl_slist_free_all(headers);
		curl_easy_cleanup(curl);

		return (res == CURLE_OK);
	}

	Anope::string EscapeJson(const Anope::string &in)
	{
		Anope::string out;
		for (char c : in)
		{
			switch (c)
			{
				case '\\': out += "\\\\"; break;
				case '"':  out += "\\\""; break;
				case '\n': out += "\\n"; break;
				case '\r': out += "\\r"; break;
				case '\t': out += "\\t"; break;
				default:   out += c; break;
			}
		}
		return out;
	}

	bool QueryOllama(const Anope::string &prompt, Anope::string &reply)
	{
		Anope::string url = Anope::printf("http://%s:%d/api/generate", host.c_str(), port);

		Anope::string json = "{";
		json += "\"model\":\"" + EscapeJson(model) + "\",";
		json += "\"prompt\":\"" + EscapeJson(prompt) + "\",";
		json += "\"stream\":false,";
		json += "\"keep_alive\":\"10m\"";
		if (!system_prompt.empty())
			json += ",\"system\":\"" + EscapeJson(system_prompt) + "\"";
		json += "}";

		Anope::string response;
		long http_code = 0;
		if (!HttpRequest(url, json, response, http_code) || http_code != 200)
		{
			Log(LOG_DEBUG) << "m_ollama: generate failed (http=" << http_code << ")";
			return false;
		}

		yyjson_doc *doc = yyjson_read(response.c_str(), response.length(), 0);
		if (!doc)
			return false;

		yyjson_val *root = yyjson_doc_get_root(doc);
		yyjson_val *resp = yyjson_obj_get(root, "response");
		if (resp && yyjson_is_str(resp))
			reply = yyjson_get_str(resp);
		else
			reply.clear();

		yyjson_doc_free(doc);
		reply.trim();
		return !reply.empty();
	}

	bool GetModels(std::vector<Anope::string> &models)
	{
		Anope::string url = Anope::printf("http://%s:%d/api/tags", host.c_str(), port);
		Anope::string response;
		long http_code = 0;
		if (!HttpRequest(url, "", response, http_code) || http_code != 200)
			return false;

		yyjson_doc *doc = yyjson_read(response.c_str(), response.length(), 0);
		if (!doc)
			return false;

		yyjson_val *root = yyjson_doc_get_root(doc);
		yyjson_val *arr = yyjson_obj_get(root, "models");
		if (arr && yyjson_is_arr(arr))
		{
			size_t idx, max;
			yyjson_val *val;
			yyjson_arr_foreach(arr, idx, max, val)
			{
				yyjson_val *name = yyjson_obj_get(val, "name");
				if (name && yyjson_is_str(name))
					models.emplace_back(yyjson_get_str(name));
			}
		}
		yyjson_doc_free(doc);
		return true;
	}

	void HandleGpt(User *u, Channel *c, const Anope::string &query)
	{
		if (query.empty())
		{
			SendReply(c, u, "Usage: " + prefix + "gpt <your question>");
			return;
		}

		Anope::string key = c->name.lower() + ":" + u->nick.lower();
		Anope::string wait_msg;
		if (!CheckRateLimit(key, wait_msg))
		{
			SendReply(c, u, wait_msg);
			return;
		}

		Anope::string clean_query = CleanIRC(query);
		Anope::string full_prompt = BuildPrompt(c->name.lower(), clean_query);

		Anope::string answer;
		if (!QueryOllama(full_prompt, answer))
		{
			SendReply(c, u, "Error connecting to Ollama service or empty response.");
			return;
		}

		answer = CleanIRC(answer);
		// Collapse excessive whitespace
		Anope::string cleaned;
		bool space = false;
		for (char ch : answer)
		{
			if (isspace(static_cast<unsigned char>(ch)))
			{
				if (!space)
					cleaned += ' ';
				space = true;
			}
			else
			{
				cleaned += ch;
				space = false;
			}
		}
		cleaned.trim();

		StoreExchange(c->name.lower(), clean_query, cleaned);
		SendReply(c, u, cleaned);
	}

public:
	ModuleOllama(const Anope::string &modname, const Anope::string &creator)
		: Module(modname, creator, THIRD)
	{
		this->SetAuthor("Grok / community");
		this->SetVersion("1.0");
		curl_global_init(CURL_GLOBAL_DEFAULT);
	}

	~ModuleOllama() override
	{
		curl_global_cleanup();
	}

	void OnReload(Configuration::Conf &conf) override
	{
		const auto &block = conf.GetModule(this);

		host = block.Get<const Anope::string>("host", "127.0.0.1");
		port = block.Get<int>("port", 11434);
		model = block.Get<const Anope::string>("model", "phi4-mini");
		system_prompt = block.Get<const Anope::string>("system_prompt", "");
		query_limit = block.Get<unsigned>("query_limit", 5);
		query_window = block.Get<time_t>("query_window", 60);
		max_context = block.Get<unsigned>("max_context", 5);
		max_response_length = block.Get<size_t>("max_response_length", 400);
		timeout = block.Get<long>("timeout", 90);
		use_bot = block.Get<bool>("use_bot", true);
		prefix = block.Get<const Anope::string>("prefix", "!");

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

		Log(LOG_NORMAL) << "m_ollama: loaded (host=" << host << ":" << port
			<< ", model=" << model
			<< ", channels=" << (all_channels ? "*" : Anope::ToString(enabled_channels.size()))
			<< ")";
	}

	void OnPrivmsg(User *u, Channel *c, Anope::string &msg, const Anope::map<Anope::string> &tags) override
	{
		if (!u || !c || msg.empty() || msg[0] == '\1')
			return;
		if (!IsChannelEnabled(c))
			return;

		Anope::string text = msg;
		text.trim();

		// Must start with the configured prefix
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

		if (cmd == "gpt")
		{
			HandleGpt(u, c, args);
		}
		else if (cmd == "gpt-status")
		{
			Anope::string url = Anope::printf("http://%s:%d/api/tags", host.c_str(), port);
			Anope::string response;
			long http_code = 0;
			if (HttpRequest(url, "", response, http_code) && http_code == 200)
				SendReply(c, u, Anope::printf("Ollama service is running on %s:%d (model: %s)", host.c_str(), port, model.c_str()));
			else
				SendReply(c, u, Anope::printf("Ollama service unreachable (HTTP %ld)", http_code));
		}
		else if (cmd == "gpt-models")
		{
			std::vector<Anope::string> models;
			if (GetModels(models) && !models.empty())
			{
				Anope::string list;
				for (size_t i = 0; i < models.size(); ++i)
				{
					if (i)
						list += ", ";
					list += models[i];
				}
				SendReply(c, u, "Available models: " + list);
			}
			else
				SendReply(c, u, "Could not fetch models list (is Ollama running?)");
		}
		else if (cmd == "gpt-model")
		{
			if (args.empty())
			{
				SendReply(c, u, "Current model is: " + model);
				SendReply(c, u, "Usage: " + prefix + "gpt-model <model_name>");
				return;
			}

			// Verify model exists
			std::vector<Anope::string> models;
			if (!GetModels(models))
			{
				SendReply(c, u, "Could not verify model availability");
				return;
			}

			bool found = false;
			for (const auto &m : models)
			{
				if (m.equals_ci(args))
				{
					found = true;
					break;
				}
			}

			if (found)
			{
				Anope::string old = model;
				model = args;
				SendReply(c, u, Anope::printf("Model changed from '%s' to '%s'", old.c_str(), model.c_str()));
				Log(LOG_NORMAL) << "m_ollama: model changed to " << model << " by " << u->nick;
			}
			else
				SendReply(c, u, "Model '" + args + "' not found. Use " + prefix + "gpt-models");
		}
		else if (cmd == "gpt-system")
		{
			if (args.empty())
			{
				if (system_prompt.empty())
					SendReply(c, u, "No custom system prompt set (using model default)");
				else
				{
					Anope::string display = system_prompt;
					if (display.length() > 200)
						display = display.substr(0, 197) + "...";
					SendReply(c, u, "Current system prompt: " + display);
				}
				SendReply(c, u, "Usage: " + prefix + "gpt-system <prompt>  or  " + prefix + "gpt-system clear");
				return;
			}

			if (args.equals_ci("clear") || args.equals_ci("reset"))
			{
				system_prompt.clear();
				SendReply(c, u, "System prompt cleared (model will use its default)");
			}
			else
			{
				system_prompt = args;
				Anope::string display = system_prompt;
				if (display.length() > 200)
					display = display.substr(0, 197) + "...";
				SendReply(c, u, "System prompt set to: " + display);
			}
		}
		else if (cmd == "gpt-clear")
		{
			ClearHistory(c->name.lower());
			SendReply(c, u, "Conversation context cleared for this channel.");
		}
	}
};

MODULE_INIT(ModuleOllama)
