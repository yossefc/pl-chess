:- module(pgn, []).

pgn_string(Move, String) :-
  phrase(move(Move), String).

unique_full_move(Position, Move, FullMove) :-
  findall(FullMove0, full_move(Position, Move, FullMove0), FullMoves),
  FullMoves = [FullMove].

full_move(Position, Move, FullMove) :-
  source_square(Move, Position, SourceSquare),
  position:list_replace(2, SourceSquare, Move, FullMove).


source_square([move, PieceType, Hint, MoveType, Destination], Position, SourceSquare) :-
  movement:officer(PieceType),
  source_square2(PieceType, Hint, MoveType, Destination, Position, SourceSquare).

source_square([move, pawn, Hint, MoveType, Destination, _Promo], Position, SourceSquare) :-
  source_square2(pawn, Hint, MoveType, Destination, Position, SourceSquare).


source_square2(PieceType, Hint, MoveType, Destination, Position, SourceSquare) :-
  fen:turn(Position, Color),
  compatible(Hint, SourceSquare),
  fen:piece_at(Position, SourceSquare, [PieceType, Color]),
  possible_move(MoveType, PieceType, SourceSquare, Destination, Position).


compatible(Square, Square) :-
  Square = [square | _].
compatible([file, File], [square, File, _]).
compatible([rank, Rank], [square, _, Rank]).
compatible(nothing, [square, _X, _Y]).


possible_move(capture, pawn, Src, Dst, P) :-
  ( fen:piece_at(P, Dst, [_, Enemy]), fen:turn(P, Color), color:opposite(Color, Enemy)
  ; fen:passant(P, Dst) ),
  
  movement:pawn_capture_square(Color, Src, Dst).

possible_move(move, pawn, Src, Dst, P) :-
  fen:piece_at(P, Dst, nothing),

  movement:pawn_move_square(Color, Src, Dst),
  fen:turn(P, Color),
  
  movement:line(Src, Dst, Line, _),
  append([[Src], Middle, [Dst]], Line),
  
  maplist(fen:piece_at(P), Middle, Pieces),
  maplist(=(nothing), Pieces).


possible_move(move, Officer, Src, Dst, P) :-
  movement:officer(Officer),
  
  fen:piece_at(P, Dst, nothing),
  possible_move(Officer, Src, Dst, P).


possible_move(capture, Officer, Src, Dst, P) :-
  movement:officer(Officer),
  fen:piece_at(P, Dst, [_, Enemy]),

  fen:turn(P, Color),
  color:opposite(Color, Enemy),

  possible_move(Officer, Src, Dst, P).


possible_move(DiagonalMover, Src, Dst, P) :-
  diagonal_mover(DiagonalMover),
  movement:diagonal(Src, Dst, Diagonal, _),
  middle_is_nothing(P,Diagonal).


possible_move(StraightMover, Src, Dst, P) :-
  straight_mover(StraightMover),
  movement:line(Src, Dst, Line, _),
  middle_is_nothing(P,Line).


possible_move(king, Src, Dst, _P) :-
  movement:diagonal(Src, Dst, Diagonal, _),
  length(Diagonal, 2).


possible_move(king, Src, Dst, _P) :-
  movement:line(Src, Dst, Diagonal, _),
  length(Diagonal, 2).


possible_move(knight, Src, Dst, _P) :-
  movement:knights_jump(Src, Dst).


middle_is_nothing(P,Squares) :-
  append([ [_], Middle, [_] ], Squares),
  maplist(fen:piece_at(P), Middle, Pieces),
  maplist(=(nothing), Pieces).


diagonal_mover(bishop).
diagonal_mover(queen).

straight_mover(queen).
straight_mover(rook).


%
%  Parsing
%

move(Castles) --> castles(Castles).

move([move, OfficerType, SourceHint, MoveType, Destination]) -->
  officer(OfficerType),
  source_hint(SourceHint),
  move_type(MoveType),
  fen:square(Destination).


move([move, pawn, SourceHint, MoveType, Destination, Promotion]) -->
  source_hint(SourceHint), { \+ SourceHint == [rank, _ ] } , 
  move_type(MoveType), 
  fen:square(Destination),
  promotion(Promotion).


move_type(move) --> [].
move_type(capture) --> "x".

source_hint([file, File]) -->
  {
    nth0(File, "abcdefgh", Char)
  },
  [Char].

source_hint([rank, Rank]) -->
  {
    nth0(Rank, "12345678", Char)
  },
  [Char].

source_hint(Square) -->
  fen:square(Square).


source_hint(nothing) --> [].


promotion(nothing) --> [].
promotion(OfficerType) -->
  "=",
  officer(OfficerType).

officer(OfficerType) -->
  {
    movement:officer(OfficerType),
    fen:piece_char([OfficerType, white], Char)
  },
  [Char].

castles([castles, queenside]) --> "O-O-O".
castles([castles, kingside]) --> "O-O".


check(Position, SourceSquare) :-
  Position = [position, Board, Color | Rest],

  % "If it were the opponents turn":
  color:opposite(Color, Opponent),
  Flipped = [position, Board, Opponent | Rest],

  % Is there a piece that can attack the king?
  fen:piece_at(Flipped, KingSquare, [king, Color]),
  attacker_of(Flipped, KingSquare, SourceSquare).


legal_position_after(FullMove, Position, Position2) :-
  fen:turn(Position, Color),

  % "In the position after FullMove":
  position:position_after(FullMove, Position, Position2),

  % "There are zero attackers of the king"
  fen:piece_at(Position2, KingSquare, [king, Color]),
  \+ attacker_of(Position2, KingSquare, _).

attacker_of(Position, AttackedSquare, SourceSquare) :-
  SourceSquare = [square, _, _],
  full_move(Position, [move, _, SourceSquare, capture, AttackedSquare | _], _).


stalemate(Position) :-
  \+ check(Position, _),
  \+ legal_position_after(_, Position, _).


checkmate(Position) :-
  check(Position, _),
  \+ legal_position_after(_, Position, _).


castling_possible(Side, Position) :-
  Position = [position, Turn, _, _, _, _],
  
  color:initial_king_square(Turn, Start),
  color:castled_king_square(Turn, Side, End),
  movement:line(Start, End, Line, _),
  append([ [Start], Middle, [End] ], Line),

  
  member(Square, Middle),
  full_move(Position, [move, _, _, capture, Square | _], _),
  !.
   
