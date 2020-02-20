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


module PuzzleGenerator

using Chess, Chess.PGN, Chess.UCI

include("engine.jl")
include("findpuzzles.jl")

end # module
