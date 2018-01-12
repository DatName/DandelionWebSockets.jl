import Base: read, write

# TODO: Documentation

"An exception thrown into a task in order to stop it."
mutable struct StopTaskException <: Exception end

abstract type AbstractServerReader end

"Reading from a network socket and placing the resulting frame on a channel."
struct ServerReader <: AbstractServerReader
    s::IO
    task::Task
end

"Read frames from the network, until an exception is thrown in this task."
function do_reader(s::IO, logic::AbstractClientTaskProxy)
    try
        sleep(10)
        while true
            frame = read(s, Frame)
            # This is a proxy, so the actual `handle` call made on the logic object is done in a
            # separate coroutine.
            handle(logic, FrameFromServer(frame))
        end
    catch ex
        @printf("[%ls][WS][Reader Task] Caught error: %ls\n", now(), ex)
        # TODO: Handle errors better.
    end
    @printf("[%ls][WS][Reader Task] Exiting\n", now())
    handle(logic, SocketClosed())
end

function start_reader(s::IO, logic::AbstractClientTaskProxy)
    ServerReader(s, @schedule do_reader(s, logic))
end


function stop(t::ServerReader)
    try
        Base.throwto(t.task, StopTaskException())
    end
end

#
#
#

"""
TLSBufferedIO adapts a TLS socket so we can do byte I/O.

The stream returned by MbedTLS when using a TLS socket does not support the byte I/O used when
reading a frame. It only supports reading a chunk of data. This is a fake stream that buffers some
data and lets us do byte I/O.

Note: This should have been done by the BufferedStreams.jl package. However, I couldn't get it to
work with the MbedTLS stream, for reasons unknown. If we can investigate and fix that problem, then
we should really replace this type with a BufferedInputStream.
"""
struct TLSBufferedIO <: IO
    tls_stream::IO
    buf::IOBuffer

    TLSBufferedIO(tls_stream::IO) = new(tls_stream, IOBuffer())
end

"Read all available data, and block until we have enough to fulfíll the next read."
function fill_buffer(s::TLSBufferedIO, n::Int)
    begin_ptr = mark(s.buf)
    while s.buf.size - begin_ptr < n
        data = readavailable(s.tls_stream)
        if isempty(data)
            throw(ErrorException("Empty data read. Closed stream?"))
        end
        write(s.buf, data)
    end
    reset(s.buf)
end

function read(s::TLSBufferedIO, t::Type{UInt8})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedIO, t::Type{UInt16})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedIO, t::Type{UInt64})
    fill_buffer(s, sizeof(t))
    read(s.buf, t)
end

function read(s::TLSBufferedIO, t::Type{UInt8}, n::Int)
    fill_buffer(s, sizeof(t) * n)
    read(s.buf, t, n)
end

write(s::TLSBufferedIO, t::UInt8) = write(s.tls_stream, t)
write(s::TLSBufferedIO, t::UInt16) = write(s.tls_stream, t)
write(s::TLSBufferedIO, t::UInt64) = write(s.tls_stream, t)
