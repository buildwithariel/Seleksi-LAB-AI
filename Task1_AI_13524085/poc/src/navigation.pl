% =====================================================================
% navigation.pl - Arah, tetangga (LIST), dan persepsi ruangan
% =====================================================================

% Perubahan koordinat (DX, DY) untuk tiap arah gerak.
offset(utara,   0, -1).
offset(selatan, 0,  1).
offset(timur,   1,  0).
offset(barat,  -1,  0).

% Daftar semua arah, dipakai adjacent_list/3 untuk cek keempat tetangga.
all_directions([utara, selatan, timur, barat]).

% CUT: sekali batas grid dicek, tidak perlu backtrack cari kemungkinan lain.
valid_position(X, Y) :-
    grid_size(N),
    X >= 1, X =< N,
    Y >= 1, Y =< N,
    !.

% Membangun LIST tetangga yang valid secara REKURSIF menyusuri
% all_directions/1.
adjacent_list(X, Y, Neighbors) :-
    all_directions(Dirs),
    adjacent_list(X, Y, Dirs, Neighbors).

adjacent_list(_, _, [], []).
adjacent_list(X, Y, [Dir|Rest], Neighbors) :-
    offset(Dir, DX, DY),
    NX is X + DX, NY is Y + DY,
    adjacent_list(X, Y, Rest, Neighbors1),
    ( valid_position(NX, NY) ->
        Neighbors = [pos(NX,NY)|Neighbors1]
    ;
        Neighbors = Neighbors1
    ).

% percept/3: mengumpulkan LIST persepsi dari ruang saat ini + tetangga,
% dibangun secara REKURSIF dari list tetangga.
percept(X, Y, Percepts) :-
    adjacent_list(X, Y, Neighbors),
    neighbor_percepts(Neighbors, NeighborPercepts),
    ( treasure(X, Y, _) -> Here = [glitter] ; Here = [] ),
    append(Here, NeighborPercepts, Percepts).

% Mengumpulkan persepsi dari tiap ruang tetangga satu per satu, lalu
% menggabungkan semuanya jadi satu list.
neighbor_percepts([], []).
neighbor_percepts([pos(NX,NY)|Rest], Percepts) :-
    room_percept_contribution(NX, NY, Contribution),
    neighbor_percepts(Rest, RestPercepts),
    append(Contribution, RestPercepts, Percepts).

% CUT: begitu diketahui ruang tetangga berisi pit, tidak perlu cek jenis lain.
room_percept_contribution(X, Y, [breeze]) :- pit(X, Y), !.
room_percept_contribution(X, Y, [stench]) :- monster(X, Y, _, alive), !.
room_percept_contribution(X, Y, [draft]) :- trapdoor(X, Y, _, _), !.
room_percept_contribution(_, _, []).

% Predicate "murni" yang sengaja dibiarkan bisa FAIL secara alami --
% berguna untuk query pengujian langsung (lihat README & test_suite.pl).
can_grab(X, Y) :- treasure(X, Y, _).
can_pickup_weapon(X, Y) :- weapon_item(X, Y, _).
at_entry(X, Y) :- entry(X, Y).
