
mutable struct LineNumberingIO
    # the number of the line last read, first line is line 1
    line::Int
    io::IO

    LineNumberingIO(io::IO) = new(0, io)
end

function LineNumberingIO(f, io::IO)
    lnio = LineNumberingIO(io)
    try
        f(lnio)
    finally
        close(lnio)
    end
end

Base.close(in::LineNumberingIO ) = close(in.io)

Base.position(in::LineNumberingIO) = position(in.io)

function Base.readline(in::LineNumberingIO; keep::Bool=false)
    in.line += 1
    readline(in.io; keep=keep)
end
