% =====================================================================
% world.pl - Fakta dunia gua & FILE PROCESSING pemuatan peta dari teks
% =====================================================================

% Fakta dinamis yang mewakili isi gua. Semuanya di-assert saat parsing
% map.txt dan direset tiap kali load_map/1 dipanggil ulang.
:- dynamic(pit/2).            % pit(X, Y)
:- dynamic(monster/4).        % monster(X, Y, Type, Status) - Status = alive/dead
:- dynamic(monster_hp/3).      % monster_hp(X, Y, HP) - HP saat ini, berubah tiap battle
:- dynamic(treasure/3).        % treasure(X, Y, Type) - Type = gold/gem/relic
:- dynamic(weapon_item/3).     % weapon_item(X, Y, Weapon) - senjata yang belum diambil
:- dynamic(trapdoor/4).        % trapdoor(X, Y, TargetX, TargetY)
:- dynamic(trapdoor_pos/2).    % posisi trapdoor sementara, dipakai resolve_trapdoors/0
:- dynamic(entry/2).           % entry(X, Y) - posisi masuk/keluar gua
:- dynamic(grid_size/1).       % grid_size(N) - ukuran grid N x N

% Nilai poin tiap jenis treasure, dipakai scoring.pl.
treasure_value(gold, 1000).
treasure_value(gem, 1500).
treasure_value(relic, 3000).

% Stat dasar tiap tipe monster: monster_base_stats(Type, HP, ATK, DEF).
monster_base_stats(kelelawar, 15, 3, 1).
monster_base_stats(laba_laba, 20, 5, 2).
monster_base_stats(goblin,    30, 6, 4).
monster_base_stats(troll,     50, 8, 7).
monster_base_stats(naga,      70, 12, 8).

% Damage dan jenis tiap senjata: weapon_stats(Weapon, Damage, Kind).
% Kind = ranged (bisa shoot dari jauh) atau melee (cuma bisa saat battle).
weapon_stats(panah,  8,  ranged).
weapon_stats(pistol, 15, ranged).
weapon_stats(pedang, 5,  melee).

% Menghapus semua fakta dunia lama sebelum memuat peta baru, supaya
% sesi baru tidak tercampur sisa sesi sebelumnya.
retractall_world :-
    retractall(pit(_,_)),
    retractall(monster(_,_,_,_)),
    retractall(monster_hp(_,_,_)),
    retractall(treasure(_,_,_)),
    retractall(weapon_item(_,_,_)),
    retractall(trapdoor(_,_,_,_)),
    retractall(trapdoor_pos(_,_)),
    retractall(entry(_,_)),
    retractall(grid_size(_)).

% Memuat peta dari file teks mentah: reset dunia, baca ukuran, baca
% seluruh baris grid, lalu selesaikan tujuan trapdoor.
load_map(FileName) :-
    retractall_world,
    open(FileName, read, Stream),
    read_line_chars(Stream, SizeLine),
    parse_size(SizeLine, N),
    assertz(grid_size(N)),
    read_all_rows(Stream, 1),
    close(Stream),
    resolve_trapdoors.

% Membaca satu baris dari stream sebagai LIST karakter, secara REKURSIF,
% karakter demi karakter memakai get_char/2 (bukan predicate siap pakai).
% Mengembalikan end_of_file hanya jika tidak ada baris lagi sama sekali.
read_line_chars(Stream, Result) :-
    get_char(Stream, C),
    ( C == end_of_file ->
        Result = end_of_file
    ; C == '\n' ->
        Result = []
    ;
        read_line_chars(Stream, Rest0),
        ( Rest0 == end_of_file -> Rest = [] ; Rest = Rest0 ),
        Result = [C|Rest]
    ).

% Membaca seluruh baris peta secara REKURSIF sampai end_of_file.
% RowY adalah nomor baris saat ini (= koordinat Y).
read_all_rows(Stream, RowY) :-
    read_line_chars(Stream, Line),
    ( Line == end_of_file ->
        true
    ; Line == [] ->
        read_all_rows(Stream, RowY)          % lewati baris kosong
    ;
        parse_row(Line, 1, RowY),
        NextY is RowY + 1,
        read_all_rows(Stream, NextY)
    ).

% Memproses satu baris (LIST karakter) menjadi fakta ruangan, REKURSIF
% karakter demi karakter; X bertambah 1 setiap karakter yang diproses.
parse_row([], _, _).
parse_row([C|Rest], X, Y) :-
    process_cell(C, X, Y),
    NextX is X + 1,
    parse_row(Rest, NextX, Y).

% Mengubah satu karakter simbol peta jadi fakta yang sesuai. CUT di
% tiap klausa karena satu karakter cuma boleh cocok satu jenis simbol.
process_cell('.', _, _) :- !.                                    % ruang kosong, tidak perlu fakta apa pun
process_cell('S', X, Y) :- !, assertz(entry(X, Y)).               % entry room
process_cell('P', X, Y) :- !, assertz(pit(X, Y)).                 % pit (jurang)
process_cell('K', X, Y) :- !, assert_monster(X, Y, kelelawar).
process_cell('L', X, Y) :- !, assert_monster(X, Y, laba_laba).
process_cell('J', X, Y) :- !, assert_monster(X, Y, goblin).
process_cell('C', X, Y) :- !, assert_monster(X, Y, troll).
process_cell('N', X, Y) :- !, assert_monster(X, Y, naga).
process_cell('G', X, Y) :- !, assertz(treasure(X, Y, gold)).
process_cell('E', X, Y) :- !, assertz(treasure(X, Y, gem)).
process_cell('R', X, Y) :- !, assertz(treasure(X, Y, relic)).
process_cell('W', X, Y) :- !, assertz(weapon_item(X, Y, pistol)).
process_cell('X', X, Y) :- !, assertz(weapon_item(X, Y, pedang)).
process_cell('T', X, Y) :- !, assertz(trapdoor_pos(X, Y)).
process_cell(_, _, _).                                            % karakter tak dikenal, abaikan saja

% Membuat fakta monster sekaligus HP awalnya, diambil dari
% monster_base_stats/4 sesuai tipe.
assert_monster(X, Y, Type) :-
    monster_base_stats(Type, HP, _, _),
    assertz(monster(X, Y, Type, alive)),
    assertz(monster_hp(X, Y, HP)).

% Trapdoor butuh tahu posisi entry, yang baru pasti diketahui setelah
% seluruh baris selesai dibaca, sehingga diselesaikan belakangan di sini.
% Contoh idiom FAIL-DRIVEN LOOP: iterasi semua trapdoor_pos/2 lewat fail.
resolve_trapdoors :-
    entry(EX, EY),
    trapdoor_pos(X, Y),
    assertz(trapdoor(X, Y, EX, EY)),
    fail.
resolve_trapdoors.

% Konversi LIST karakter angka (boleh diawali '-') menjadi integer,
% REKURSIF, tanpa bergantung pada predicate konversi bawaan. Dipakai
% untuk membaca ukuran grid di baris pertama file peta.
parse_size(Chars, N) :-
    split_on_spaces(Chars, [FirstTok|_]),
    chars_to_number(FirstTok, N).

% Memecah list karakter jadi beberapa token berdasarkan spasi.
split_on_spaces(Chars, Tokens) :-
    split_on_spaces(Chars, [], Tokens).

split_on_spaces([], Acc, [Rev]) :-
    reverse(Acc, Rev).
split_on_spaces([' '|T], Acc, [Rev|Rest]) :-
    !,
    reverse(Acc, Rev),
    split_on_spaces(T, [], Rest).
split_on_spaces([C|T], Acc, Rest) :-
    split_on_spaces(T, [C|Acc], Rest).

% Mengubah list karakter digit jadi integer, boleh diawali tanda '-'.
chars_to_number(['-'|Rest], N) :-
    !,
    chars_to_number(Rest, 0, Pos),
    N is -Pos.
chars_to_number(Chars, N) :-
    chars_to_number(Chars, 0, N).

chars_to_number([], Acc, Acc).
chars_to_number([C|Rest], Acc, N) :-
    char_code(C, Code),
    Digit is Code - 0'0,
    Digit >= 0, Digit =< 9,
    NewAcc is Acc * 10 + Digit,
    chars_to_number(Rest, NewAcc, N).
