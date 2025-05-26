extends Node

## Connects a signal to a callable without throwing errors if it's already connected
@warning_ignore("int_as_enum_without_match", "int_as_enum_without_cast")
func _connect(sig: Signal, callable: Callable, flags: ConnectFlags = 0) -> bool:
	if callable.is_null() || !callable.is_valid(): return true
	if sig.is_connected(callable): return true
	sig.connect(callable, flags)
	return false


## Disconnects a signal from a callable without throwing errors if it's already disconnected
func _disconnect(sig: Signal, callable: Callable) -> bool:
	if callable.is_null() || !callable.is_valid(): return true
	if !sig.is_connected(callable): return true
	sig.disconnect(callable)
	return false
