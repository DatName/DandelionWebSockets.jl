import Nettle
import Requests

# TODO: Documentation

immutable HandshakeResult
    expected_accept::ASCIIString
    stream::IO
    headers::Dict{ASCIIString,ASCIIString}
    body::Vector{UInt8}
end

immutable HandshakeFailure

end

function validate(handshake::HandshakeResult)
    accept_name = "Sec-WebSocket-Accept"
    if !haskey(handshake.headers, accept_name)
        println("No key $accept_name in $(handshake.headers)")
        return false
    end

    accept_value = handshake.headers[accept_name]

    is_valid = accept_value == handshake.expected_accept
    if !is_valid
        println("Expected accept value $(handshake.expected_accept) does not match actual $accept_value")
    end

    is_valid
end

function make_websocket_key(rng::AbstractRNG)
    ascii(base64encode(rand(rng, UInt8, 16)))
end

function calculate_accept(key::ASCIIString)
    magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    h = Nettle.digest("sha1", key * magic)
    base64encode(h)
end

function make_headers(key::ASCIIString)
    headers = Dict(
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => key,
        "Sec-WebSocket-Version" => "13")
end

function do_handshake(rng::AbstractRNG, uri::Requests.URI; do_request=Requests.do_stream_request)
    key = make_websocket_key(rng)
    expected_accept = calculate_accept(key)
    headers = make_headers(key)
    result = do_request(uri, ascii("GET"); headers=headers)

    HandshakeResult(expected_accept, result.socket, Dict(), b"")
end

function convert_ws_uri(uri::Requests.URI)
    u = replace(string(uri), r"^ws", "http")
    Requests.URI(u)
end