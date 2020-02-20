#=
        PuzzleGenerator.jl: Code for generating tactical puzzles from PGN files.
        Copyright (C) 2020 Play Magnus AS

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU Affero General Public License as
        published by the Free Software Foundation, either version 3 of the
        License, or (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU Affero General Public License for more details.

        You should have received a copy of the GNU Affero General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>.
=#


"""
    startengine(;enginepath="stockfish", ttsize=256, threads=1)

Starts and initializes a UCI chess engine with the supplied engine executable
name, transposition table size, and thread count.
"""
function startengine(;enginepath="stockfish", ttsize=256, threads=1)::Engine
    e = runengine(enginepath)
    setoption(e, "Hash", ttsize)
    setoption(e, "Threads", threads)
    e
end


"""
    mpvsearch(g::SimpleGame, e::Engine; nodes, pvs)

Performs a multi-PV search to the requested node count.

The return value is a vector of `SearchInfo` values, one for each PV.
"""
function mpvsearch(g::Union{Board, SimpleGame, Game}, e::Engine;
                   nodes::Int, pvs::Int)::Vector{SearchInfo}

    result = SearchInfo[]

    function infoaction(info::String)
        info = parsesearchinfo(info)
        if !isnothing(info.multipv)
            info.multipv == 1 && empty!(result)
            push!(result, info)
        end
    end

    setoption(e, "MultiPV", pvs)
    setboard(e, g)
    search(e, "go nodes $nodes", infoaction = infoaction)

    result
end


"""
    iswon(info::SearchInfo, threshold = 280)

Tests whether a `SearchInfo` line has a score corresponding to a win.

The optional variable `threshold` is the limit (in centipawns) for when the
position should be considered won. The function returns `true` if the score
is a positive mate score or more than `threshold` centipawns.
"""
function iswon(info::SearchInfo, threshold::Int = 280)::Bool
    s = info.score
    (s.ismate && s.value > 0) || (!s.ismate && s.value > threshold)
end


"""
    islost(info::SearchInfo, threshold = 280)

Tests whether a `SearchInfo` line has a score corresponding to a loss.

The optional variable `threshold` is the limit (in centipawns) for when the
position should be considered lost. The function returns `true` if the score
is a negative mate score or less than `-threshold` centipawns.
"""
function islost(info::SearchInfo, threshold::Int = 280)::Bool
    s = info.score
    (s.ismate && s.value < 0) || (!s.ismate && s.value < -threshold)
end


"""
    isnotwon(info::SearchInfo, threshold = 100)

Tests whether a `SearchInfo` line does not look like a clear win.

The optional variable `threshold` is the limit (in centipawns) for when the
position should be not clearly winning. The function returns `true` if the
score is a negative mate score or less than `threshold` centipawns.
"""
function isnotwon(info::SearchInfo, threshold::Int = 100)::Bool
    s = info.score
    (s.ismate && s.value < 0) || (!s.ismate && s.value < threshold)
end


"""
    isnotlost(info::SearchInfo, threshold = 100)

Tests whether a `SearchInfo` line does not look like a clear loss.

The optional variable `threshold` is the limit (in centipawns) for when the
position should be not clearly lost. The function returns `true` if the
score is a positive mate score or more than `-threshold` centipawns.
"""
function isnotlost(info::SearchInfo, threshold::Int = 100)::Bool
    s = info.score
    (s.ismate && s.value > 0) || (!s.ismate && s.value > -threshold)
end


"""
    onewinningmove(g::SimpleGame, e::Engine; nodes::Int)

Tests whether there appears to be exactly one winning move.
"""
function onewinningmove(g::SimpleGame, e::Engine, nodes::Int)::Bool
    sr = mpvsearch(g, e, nodes = nodes, pvs = 2)
    length(sr) >= 2 && iswon(sr[1]) && all(isnotwon, sr[2:end])
end
