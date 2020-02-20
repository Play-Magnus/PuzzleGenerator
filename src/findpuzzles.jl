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
    isgoodpuzzle(g::SimpleGame, e::Engine, nodes::Int)

Tests whether a candidate puzzle is actually a usable puzzle.

The current position in the game is assumed to be a position where there
appears (based on a shallow search) exactly one winning move. This function
verifies a number of additional criterions and searches the position more
deeply to ensure the position is suitable for use as a puzzle.
"""
function isgoodpuzzle(g::SimpleGame, e::Engine, nodes::Int)::Bool
    # If the side to move is in check, discard the puzzle.
    if ischeck(board(g))
        return false
    end

    # If the position is not won, or there is more than one winning move,
    # discard the puzzle.
    searchresult = mpvsearch(g, e, nodes = nodes, pvs = 2)
    if !iswon(searchresult[1]) || any(iswon, searchresult[2:end])
        return false
    end

    # If the winning move is a mate in 1, discard the puzzle.
    if searchresult[1].score.ismate && searchresult[1].score.value == 1
        return false
    end

    # Extract the winning move:
    m = searchresult[1].pv[1]

    # If the winning move is an en passant capture, discard the puzzle.
    if ptype(pieceon(board(g), from(m))) == PAWN && to(m) == epsquare(board(g))
        return false
    end

    # If the winning move is a queen promotion, discard the puzzle.
    if ispromotion(m) && promotion(m) == QUEEN
        return false
    end

    # Find the static exchange evaluation value of the move. This is a very
    # simple estimate of the material loss or gain of the move, obtained by
    # looking at all attackers and defenders of the destination square,
    # without taking into account factors like pinned or overloaded pieces.
    #
    # The value will be positive for moves that look like simple material
    # winning captures, negative for moves that appear to lose material,
    # and zero for all other moves.
    seeval = see(board(g), m)

    # If the winning move is a simple material gaining capture, discard the
    # puzzle.
    if seeval > 0
        return false
    end

    # If the best move looks like a sacrifice, accept the puzzle.
    if seeval < 0
        return true
    end

    # If the best move was not played in the game, accept the puzzle.
    if nextmove(g) != m
        return true
    end

    # If the previous position was not lost, accept the puzzle.
    if !isatbeginning(g)
        back!(g)
        searchresult = mpvsearch(g, e, nodes = nodes, pvs = 1)
        forward!(g)
        return length(searchresult) > 0 && isnotlost(searchresult[1])
    end

    # If we get here, it means that the side to move found the winning move,
    # the winning move was not a capture, and the opponent was already lost
    # before making his last move. It's likely that the winning move is too
    # easy to find and that this isn't an interesting puzzle, so we discard
    # it.
    false
end


"""
    puzzlesingame(g::SimpleGame, e::Engine)

Returns a list of positions in the input game that appear to be suitable for
use as puzzles.

The return value is a (possibly empty) vector of FEN strings.
"""
function puzzlesingame(g::SimpleGame, e::Engine)::Vector{String}
    result = String[]

    # Go through the game, checking each position to see whether it could be
    # suitable for a puzzle.
    while !isatend(g)

        # We require that a puzzle position has exactly one winning move.
        # Test this by a shallow search.
        if onewinningmove(g, e, 1_000_000)
            ispuzzlecandidate = true

            # Search gradually more deeply, verifying that the position
            # satisfies all criterions for a good puzzle at all depths.
            nodes = 1_000_000
            while nodes <= 40_000_000
                if !isgoodpuzzle(g, e, nodes)
                    ispuzzlecandidate = false
                    break
                end
                nodes = round(Int, 1.4 * nodes)
            end

            # If the puzzle still looks OK, save it to the result vector.
            if ispuzzlecandidate
                push!(result, fen(board(g)))
            end
        end

        # Go forward to the next position in the game, and continue the loop.
        forward!(g)
    end

    result
end


"""
    puzzlesfrompgn(pgnfilename::String, outputfilename::String)

Scan through all games in `pgnfilname` and write puzzle FENS to `outputfilename`.
"""
function puzzlesfrompgn(pgnfilename::String, outputfilname::String)
    e = startengine();
    gamecount = 0
    puzzlecount = 0

    for g ∈ gamesinfile(pgnfilename)
        gamecount += 1
        for pz ∈ puzzlesingame(g, e)
            puzzlecount += 1
            open(outputfilname, "a") do outputfile
                println(outputfile, pz)
            end
        end
        println("$gamecount games, $puzzlecount puzzles")
    end
end
