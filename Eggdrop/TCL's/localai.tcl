#!/usr/bin/env tclsh
# Eggdrop Ollama Integration Script
# Responds to !gpt commands by querying Ollama instance via WireGuard
# Modifyed by Cjefke 2026 - Https://IRCPlus.nl - irc.IRCPlus.nl

# Configuration
set ollama_host "127.0.0.1"
set ollama_port "11434"
set ollama_model "phi4-mini"  ;# Change this to your preferred model
set ollama_system_prompt ""  ;# Custom system prompt (empty = use model default)
set max_response_length 400  ;# Maximum characters for IRC response
set timeout 120  ;# Timeout in seconds for HTTP requests

# Rate limiting configuration
set query_limit 5  ;# Maximum queries per time window
set query_window 60  ;# Time window in seconds (60 = 1 minute)
set query_tracker [dict create]

# Conversation context configuration
set max_context_messages 5  ;# Number of previous exchanges to remember
set conversation_history [dict create]

# Load required packages
package require http
package require json
package require tls

# Register SSL support for HTTPS if needed
::http::register https 443 [list ::tls::socket -autoservername true]

# Bind the trigger to the procedure
bind pub - "!gpt" gpt_query

# Main procedure to handle !gpt commands
# Helper procedure om IRC controle- en kleurtekens (inclusief \x19) te strippen
proc clean_irc_text {text} {
    # Verwijdert \x03 followed by optional color digits (e.g. \x0304,99)
    regsub -all {\x03[0-9]{0,2}(,[0-9]{0,2})?} $text "" text
    # Verwijdert overige sturingstekens: \x02(vet), \x0F(reset), \x16(reverse), \x1F(under), \x1D(italic), \x19(mIRC-color)
    regsub -all {[\x02\x0F\x16\x1F\x1D\x19]} $text "" text
    return $text
}

# Main procedure to handle !gpt commands
proc gpt_query {nick uhost hand chan text} {
    global ollama_host ollama_port ollama_model ollama_system_prompt max_response_length timeout
    global query_tracker query_limit query_window conversation_history max_context_messages
    
    # Check if user provided a query
    set query [string trim $text]
    if {$query eq ""} {
        putserv "PRIVMSG $chan :Usage: !gpt <your question>"
        return
    }
    
    # Maak de input van de gebruiker direct schoon van IRC troep
    set query [clean_irc_text $query]
    
    # Rate limiting check
    set current_time [clock seconds]
    set user_key "${chan}:${nick}"
    
    if {[dict exists $query_tracker $user_key]} {
        set user_queries [dict get $query_tracker $user_key]
        # Filter queries within the time window
        set recent_queries [list]
        foreach query_time $user_queries {
            if {[expr $current_time - $query_time] < $query_window} {
                lappend recent_queries $query_time
            }
        }
        
        if {[llength $recent_queries] >= $query_limit} {
            putserv "PRIVMSG $chan :\002$nick\002: Rate limit exceeded. Please wait [expr $query_window - ($current_time - [lindex $recent_queries 0])] seconds."
            return
        }
        
        # Update tracker with filtered list plus new query
        lappend recent_queries $current_time
        dict set query_tracker $user_key $recent_queries
    } else {
        dict set query_tracker $user_key [list $current_time]
    }
    
    # Build context-aware prompt
    set context_key $chan
    set full_prompt $query
    
    if {[dict exists $conversation_history $context_key]} {
        set history [dict get $conversation_history $context_key]
        if {[llength $history] > 0} {
            set context_prompt "Previous conversation:\n"
            foreach exchange $history {
                lassign $exchange user_msg assistant_msg
                # Zorg dat zowel oude vragen als oude antwoorden 100% schoon zijn
                set user_msg [clean_irc_text $user_msg]
                set assistant_msg [clean_irc_text $assistant_msg]
                append context_prompt "User: $user_msg\nAssistant: $assistant_msg\n"
            }
            append context_prompt "\nCurrent question: $query"
            set full_prompt $context_prompt
        }
    }
    
    # Sanitize the query for JSON
    set full_prompt [string map {"\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"} $full_prompt]
    
    # Prepare JSON payload for Ollama API (with keep-alive to speed up subsequent queries)
    if {$ollama_system_prompt ne ""} {
        # Sanitize system prompt for JSON
        set sys_prompt [string map {"\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"} $ollama_system_prompt]
        set json_data "{\"model\": \"$ollama_model\", \"prompt\": \"$full_prompt\", \"system\": \"$sys_prompt\", \"stream\": false, \"keep_alive\": \"10m\"}"
    } else {
        set json_data "{\"model\": \"$ollama_model\", \"prompt\": \"$full_prompt\", \"stream\": false, \"keep_alive\": \"10m\"}"
    }
    
    # Make HTTP request to Ollama
    set url "http://${ollama_host}:${ollama_port}/api/generate"
    
    putlog "Querying Ollama at $url with model $ollama_model (user: $nick, chan: $chan)"
    putlog "JSON payload: $json_data"
    
    # Start a timer for progress updates on long queries
    set progress_timer [after 15000 [list progress_update $chan $nick]]
    
    # Configure HTTP request
    set headers [list "Content-Type" "application/json" "User-Agent" "EggdropBot/1.0"]
    
    # Set up the HTTP request with error handling
    if {[catch {
        set token [::http::geturl $url \
            -headers $headers \
            -query $json_data \
            -timeout [expr $timeout * 1000] \
            -method POST]
    } error]} {
        after cancel $progress_timer
        putlog "HTTP request failed: $error"
        putserv "PRIVMSG $chan :\002$nick\002: Error connecting to Ollama service."
        return
    }
    
    # Cancel the progress timer since we have a response
    after cancel $progress_timer
    
    # Check HTTP status
    set status [::http::status $token]
    set ncode [::http::ncode $token]
    set response_data [::http::data $token]
    
    putlog "HTTP Status: $status, Code: $ncode"
    putlog "Raw response: [string range $response_data 0 200]..."
    
    if {$status ne "ok" || $ncode != 200} {
        putlog "HTTP request failed with status: $status, code: $ncode"
        putlog "Error response: $response_data"
        putserv "PRIVMSG $chan :\002$nick\002: Ollama service returned an error (HTTP $ncode). Check logs for details."
        ::http::cleanup $token
        return
    }
    
    # Get response data (already retrieved above)
    ::http::cleanup $token
    
    # Parse JSON response
    if {[catch {set response_dict [::json::json2dict $response_data]} error]} {
        putlog "JSON parsing failed: $error"
        putserv "PRIVMSG $chan :\002$nick\002: Invalid response from Ollama service."
        return
    }
    
    # Extract the response text
    if {[dict exists $response_dict "response"]} {
        set ollama_response [dict get $response_dict "response"]
    } else {
        putlog "No 'response' field in Ollama response: $response_data"
        putserv "PRIVMSG $chan :\002$nick\002: Unexpected response format from Ollama."
        return
    }
    
    # Clean up the response
    set ollama_response [string trim $ollama_response]
    
    # Store in conversation history (Schoongemaakte varianten opslaan)
    if {![dict exists $conversation_history $context_key]} {
        dict set conversation_history $context_key [list]
    }
    
    set history [dict get $conversation_history $context_key]
    lappend history [list [clean_irc_text $query] [clean_irc_text $ollama_response]]
    
    # Keep only the last N exchanges
    if {[llength $history] > $max_context_messages} {
        set history [lrange $history end-[expr $max_context_messages - 1] end]
    }
    
    dict set conversation_history $context_key $history
    
    # Split long responses into multiple messages
    send_response $chan $nick $ollama_response $max_response_length
}



# Helper procedure for progress updates on long queries
proc progress_update {chan nick} {
    putserv "PRIVMSG $chan :\002$nick\002: Still processing... (complex queries can take time)"
}

# Helper procedure to send responses, splitting long messages
proc send_response {chan nick response max_length} {
    # Remove excessive whitespace and newlines
    regsub -all {\s+} $response " " response
    set response [string trim $response]
    
    if {$response eq ""} {
        putserv "PRIVMSG $chan :\002$nick\002: Ollama returned an empty response."
        return
    }
    
    # If response is short enough, send it as one message
    if {[string length $response] <= $max_length} {
        putserv "PRIVMSG $chan :\002$nick\002: $response"
        return
    }
    
    # Split long responses
    set words [split $response " "]
    set current_message ""
    set message_count 1
    
    foreach word $words {
        set potential_message "$current_message $word"
        if {[string length $potential_message] > $max_length} {
            if {$current_message ne ""} {
                putserv "PRIVMSG $chan :\002$nick\002 ($message_count): [string trim $current_message]"
                incr message_count
                set current_message $word
            } else {
                # Single word too long, truncate it
                set truncated [string range $word 0 [expr $max_length - 10]]
                putserv "PRIVMSG $chan :\002$nick\002 ($message_count): ${truncated}..."
                incr message_count
                set current_message ""
            }
        } else {
            set current_message $potential_message
        }
    }
    
    # Send any remaining message
    if {[string trim $current_message] ne ""} {
        putserv "PRIVMSG $chan :\002$nick\002 ($message_count): [string trim $current_message]"
    }
}

# Optional: Add a command to clear conversation context
proc gpt_clear {nick uhost hand chan text} {
    global conversation_history
    
    set context_key $chan
    
    if {[dict exists $conversation_history $context_key]} {
        dict unset conversation_history $context_key
        putserv "PRIVMSG $chan :\002$nick\002: Conversation context cleared for this channel."
        putlog "Conversation context cleared by $nick in $chan"
    } else {
        putserv "PRIVMSG $chan :\002$nick\002: No conversation context to clear."
    }
}

# Optional: Add a command to check Ollama status
bind pub - "!gpt-status" gpt_status

proc gpt_status {nick uhost hand chan text} {
    global ollama_host ollama_port timeout
    
    set url "http://${ollama_host}:${ollama_port}/api/tags"
    
    if {[catch {
        set token [::http::geturl $url -timeout [expr $timeout * 1000]]
        set status [::http::status $token]
        set ncode [::http::ncode $token]
        ::http::cleanup $token
        
        if {$status eq "ok" && $ncode == 200} {
            putserv "PRIVMSG $chan :\002$nick\002: Ollama service is running on $ollama_host:$ollama_port"
        } else {
            putserv "PRIVMSG $chan :\002$nick\002: Ollama service unreachable (HTTP $ncode)"
        }
    } error]} {
        putserv "PRIVMSG $chan :\002$nick\002: Cannot connect to Ollama service: $error"
    }
}

# Optional: Add a command to list available models
bind pub - "!gpt-models" gpt_models

# Optional: Add a command to change the current model
bind pub - "!gpt-model" gpt_model

# Optional: Add a command to set/view custom system prompt
bind pub - "!gpt-system" gpt_system

# Optional: Add a command to clear conversation context
bind pub - "!gpt-clear" gpt_clear

# Optional: Add a command to change the current model
proc gpt_model {nick uhost hand chan text} {
    global ollama_host ollama_port ollama_model timeout
    
    set new_model [string trim $text]
    
    # If no model specified, show current model
    if {$new_model eq ""} {
        putserv "PRIVMSG $chan :\002$nick\002: Current model is: $ollama_model"
        putserv "PRIVMSG $chan :\002$nick\002: Usage: !gpt-model <model_name> (use !gpt-models to see available models)"
        return
    }
    
    # First, let's verify the model exists by checking the models list
    set url "http://${ollama_host}:${ollama_port}/api/tags"
    
    if {[catch {
        set token [::http::geturl $url -timeout [expr $timeout * 1000]]
        set status [::http::status $token]
        set ncode [::http::ncode $token]
        
        if {$status eq "ok" && $ncode == 200} {
            set response_data [::http::data $token]
            if {[catch {set response_dict [::json::json2dict $response_data]} error]} {
                putserv "PRIVMSG $chan :\002$nick\002: Could not verify model availability"
                ::http::cleanup $token
                return
            } else {
                set model_found 0
                if {[dict exists $response_dict "models"]} {
                    set models_list [dict get $response_dict "models"]
                    foreach model $models_list {
                        if {[dict exists $model "name"]} {
                            set model_name [dict get $model "name"]
                            if {$model_name eq $new_model} {
                                set model_found 1
                                break
                            }
                        }
                    }
                }
                
                if {$model_found} {
                    set old_model $ollama_model
                    set ollama_model $new_model
                    putserv "PRIVMSG $chan :\002$nick\002: Model changed from '$old_model' to '$ollama_model'"
                    putlog "Model changed by $nick from '$old_model' to '$ollama_model'"
                } else {
                    putserv "PRIVMSG $chan :\002$nick\002: Model '$new_model' not found. Use !gpt-models to see available models."
                }
            }
        } else {
            putserv "PRIVMSG $chan :\002$nick\002: Could not verify model availability (HTTP $ncode)"
        }
        ::http::cleanup $token
    } error]} {
        putserv "PRIVMSG $chan :\002$nick\002: Error checking model availability: $error"
    }
}

# Optional: Add a command to set/view custom system prompt
proc gpt_system {nick uhost hand chan text} {
    global ollama_system_prompt
    
    set new_prompt [string trim $text]
    
    # If no prompt specified, show current prompt
    if {$new_prompt eq ""} {
        if {$ollama_system_prompt eq ""} {
            putserv "PRIVMSG $chan :\002$nick\002: No custom system prompt set (using model default)"
        } else {
            # Truncate display if too long
            set display_prompt $ollama_system_prompt
            if {[string length $display_prompt] > 200} {
                set display_prompt "[string range $display_prompt 0 196]..."
            }
            putserv "PRIVMSG $chan :\002$nick\002: Current system prompt: $display_prompt"
        }
        putserv "PRIVMSG $chan :\002$nick\002: Usage: !gpt-system <prompt> or !gpt-system clear"
        return
    }
    
    # Handle clearing the prompt
    if {[string tolower $new_prompt] eq "clear" || [string tolower $new_prompt] eq "reset"} {
        set ollama_system_prompt ""
        putserv "PRIVMSG $chan :\002$nick\002: System prompt cleared (model will use its default)"
        putlog "System prompt cleared by $nick"
        return
    }
    
    # Set the new system prompt
    set ollama_system_prompt $new_prompt
    set display_prompt $new_prompt
    if {[string length $display_prompt] > 200} {
        set display_prompt "[string range $display_prompt 0 196]..."
    }
    putserv "PRIVMSG $chan :\002$nick\002: System prompt set to: $display_prompt"
    putlog "System prompt changed by $nick to: $new_prompt"
}

proc gpt_models {nick uhost hand chan text} {
    global ollama_host ollama_port timeout
    
    set url "http://${ollama_host}:${ollama_port}/api/tags"
    
    if {[catch {
        set token [::http::geturl $url -timeout [expr $timeout * 1000]]
        set status [::http::status $token]
        set ncode [::http::ncode $token]
        
        if {$status eq "ok" && $ncode == 200} {
            set response_data [::http::data $token]
            if {[catch {set response_dict [::json::json2dict $response_data]} error]} {
                putserv "PRIVMSG $chan :\002$nick\002: Could not parse models list"
            } else {
                if {[dict exists $response_dict "models"]} {
                    set models_list [dict get $response_dict "models"]
                    set model_names {}
                    foreach model $models_list {
                        if {[dict exists $model "name"]} {
                            lappend model_names [dict get $model "name"]
                        }
                    }
                    if {[llength $model_names] > 0} {
                        putserv "PRIVMSG $chan :\002$nick\002: Available models: [join $model_names ", "]"
                    } else {
                        putserv "PRIVMSG $chan :\002$nick\002: No models found"
                    }
                } else {
                    putserv "PRIVMSG $chan :\002$nick\002: No models list in response"
                }
            }
        } else {
            putserv "PRIVMSG $chan :\002$nick\002: Could not fetch models list (HTTP $ncode)"
        }
        ::http::cleanup $token
    } error]} {
        putserv "PRIVMSG $chan :\002$nick\002: Error fetching models: $error"
    }
}

putlog "Ollama integration script loaded - listening for !gpt commands"
putlog "Ollama host: $ollama_host:$ollama_port, Model: $ollama_model"
putlog "Rate limiting: $query_limit queries per $query_window seconds"
putlog "Conversation context: keeping last $max_context_messages exchanges"
if {$ollama_system_prompt ne ""} {
    putlog "Custom system prompt active: [string range $ollama_system_prompt 0 100]..."
}
