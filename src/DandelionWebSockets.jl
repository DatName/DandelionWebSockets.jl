module DandelionWebSockets

using Compat

export AbstractWSClient,
       WSClient,
       stop,
       send_text,
       send_binary

export WebSocketHandler,
       on_text,
       on_binary,
       state_closed,
       state_closing,
       state_connecting,
       state_open,
       wsconnect

abstract type AbstractWSClient end

# This defines the public interface that the user should implement. These are callbacks called when
# events arrive from this WebSocket library.
abstract type WebSocketHandler end

"Handle a text frame."
function on_text(t::WebSocketHandler, ::String)
    T = typeof(t)
    throw(ErrorException("Method `on_text` is not implemented by $T"))
end

"Handle a binary frame."
function on_binary(t::WebSocketHandler, ::Vector{UInt8})
    T = typeof(t)
    throw(ErrorException("Method `on_binary` is not implemented by $T"))
end

"The WebSocket was closed."
state_closed(t::WebSocketHandler) = @printf("[%ls][WS:Closed]\n", now())

"The WebSocket is about to close."
state_closing(t::WebSocketHandler) = @printf("[%ls][WS:Closing]\n", now())

"The WebSocket is trying to connect."
state_connecting(t::WebSocketHandler) = @printf("[%ls][WS:Connecting]\n", now())

"The WebSocket is open and ready to send and receive messages."
state_open(t::WebSocketHandler) = @printf("[%ls][WS:Opened]\n", now())

include("core.jl")
include("taskproxy.jl")
include("glue_interface.jl")
include("network.jl")
include("client_logic.jl")
include("ping.jl")
include("handshake.jl")
include("client.jl")
include("reconnect.jl")
include("mock.jl")

end # module
