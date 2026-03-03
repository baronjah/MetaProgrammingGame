extends Node

const SERVER_URL := "http://localhost:8080"

var prefix_prompt: String = ""
var suffix_prompt: String = ""
var http: HTTPRequest

func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

func send_message(content: String, agent_mode: String = "default") -> void:
	var payload := build_payload(content, agent_mode)
	var body := JSON.stringify(payload)
	var err := http.request(
		"%s/message" % SERVER_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		Scriptura.push_message("Bridge request dispatch failed: %s" % err, "ConsciousnessBridge")

func build_payload(content: String, mode: String) -> Dictionary:
	var start := maxi(Scriptura.message_log.size() - 10, 0)
	return {
		"prefix": prefix_prompt,
		"messages": Scriptura.message_log.slice(start, Scriptura.message_log.size()),
		"suffix": suffix_prompt,
		"mode": mode,
		"content": content,
	}

func parse_response(body: String) -> void:
	var parsed := JSON.parse_string(body)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("content"):
		body = str(parsed["content"])
	for token in Scriptura.parse_for_tokens(body):
		Scriptura.snap_function(token)
	Scriptura.push_message(body, "agent")

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code < 200 or response_code >= 300:
		Scriptura.push_message("Bridge request failed: %s" % response_code, "ConsciousnessBridge")
		return
	parse_response(body.get_string_from_utf8())
