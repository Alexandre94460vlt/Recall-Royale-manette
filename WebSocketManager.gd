# WebSocketManager.gd
# Add this as Autoload: Project > Project Settings > Autoload

extends Node

signal input_received(data: Dictionary)
signal controller_connected(peer_id: int)
signal controller_disconnected(peer_id: int)

const PORT = 8080

var _server := WebSocketMultiplayerPeer.new()
var connected_controllers: Array[int] = []


func _ready() -> void:
	var err = _server.create_server(PORT)
	if err != OK:
		push_error("Failed to start WebSocket server on port %d" % PORT)
		return
	print("✅ WebSocket server started on port ", PORT)
	print("📱 Connect your phone to: ws://<YOUR_PC_IP>:", PORT)
	
	# Connect to the built-in signals of WebSocketMultiplayerPeer
	_server.peer_connected.connect(_on_peer_connected)
	_server.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	# Must poll every frame
	_server.poll()
	
	# Read all incoming packets
	while _server.get_available_packet_count() > 0:
		var raw: PackedByteArray = _server.get_packet()
		var sender_id: int       = _server.get_packet_peer()
		var text: String         = raw.get_string_from_utf8()
		
		var json := JSON.new()
		if json.parse(text) != OK:
			continue
		
		_handle_message(sender_id, json.get_data())


func _handle_message(peer_id: int, msg: Dictionary) -> void:
	match msg.get("type", ""):
		
		"register":
			if msg.get("role") == "controller":
				if peer_id not in connected_controllers:
					connected_controllers.append(peer_id)
					print("🎮 Controller connected — peer_id: ", peer_id)
					emit_signal("controller_connected", peer_id)
					
					# Send assigned ID back to the phone
					var reply = JSON.stringify({ "type": "assign_id", "id": peer_id })
					_server.set_target_peer(peer_id)
					_server.put_packet(reply.to_utf8_buffer())
		
		"input":
			var data := {
				"peer_id": peer_id,
				"x":       int(msg.get("x", 0)),
				"y":       int(msg.get("y", 0)),
				"buttons": msg.get("buttons", {})
			}
			emit_signal("input_received", data)


func _on_peer_connected(peer_id: int) -> void:
	print("📡 Peer connected: ", peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	connected_controllers.erase(peer_id)
	print("❌ Controller disconnected: ", peer_id)
	emit_signal("controller_disconnected", peer_id)
