% =====================================================================
% mapgen.pl - Peta Prosedural (Spesifikasi Bonus B2) & pemilihan sumber
% peta di awal permainan (file yang sudah ada ATAU generate acak).
%
% generate_map/3 menghasilkan peta acak lalu MENULISKANNYA KE FILE
% dengan format sama seperti map.txt biasa (File Processing), supaya
% tetap dimuat lewat load_map/1 yang sama -- konsisten dengan alur
% berbasis file, bukan jalur pintas assert langsung ke memori.
% =====================================================================

:- dynamic(gen_cell/3).

% difficulty_params(Difficulty, NumPits, NumMonsters, NumTreasures, NumWeapons, MonsterSymbols)
difficulty_params(mudah,  2, 2, 4, 2, ['K','L']).
difficulty_params(sedang, 4, 4, 3, 2, ['K','L','J']).
difficulty_params(sulit,  6, 5, 2, 1, ['J','C','N']).

% Deskripsi ringkas tiap tingkat kesulitan untuk ditampilkan ke pemain.
% Catatan: kalau difficulty_params/6 di atas diubah, sesuaikan juga teks
% di bawah ini supaya tetap akurat.
difficulty_description(mudah,  '2 pit, 2 monster lemah (kelelawar/laba-laba), 4 treasure, 2 senjata').
difficulty_description(sedang, '4 pit, 4 monster sedang (kelelawar/laba-laba/goblin), 3 treasure, 2 senjata').
difficulty_description(sulit,  '6 pit, 5 monster kuat (goblin/troll/naga), 2 treasure, 1 senjata').

% Katalog peta yang sudah disediakan, ditampilkan saat pemain memilih
% opsi "gunakan file yang sudah ada".
known_map('map.txt', 'Peta utama 5x5 - 1 pit, 1 laba-laba, gold+relic+pistol+pedang+trapdoor. Cocok untuk pemula.').

% --- Menu pemilihan sumber peta ---

% Entry point menu: tanya sumber peta dulu, baru mulai permainan.
choose_map_and_start :-
    format("~n=== PILIH SUMBER PETA ===~n", []),
    format("1. Gunakan file peta yang sudah ada~n", []),
    format("2. Generate peta acak (Peta Prosedural)~n", []),
    ask_map_choice(MapFile),
    start_game(MapFile).

% REKURSIF: kembali bertanya (LOOP) selama pilihan tidak dikenali.
ask_map_choice(MapFile) :-
    format("Pilihan (1/2) > ", []),
    read(Choice),
    ( Choice == 1 ->
        format("~nPeta yang tersedia:~n", []),
        list_known_maps,
        format("(atau ketik nama file peta lain, mis. hasil generate sebelumnya)~n", []),
        format("Masukkan nama file peta (contoh: map.txt, TANPA tanda kutip/titik) > ", []),
        read_filename(MapFile)
    ; Choice == 2 ->
        format("Masukkan ukuran grid N (mis. 6) > ", []),
        read(Size),
        format("~nTingkat kesulitan yang tersedia:~n", []),
        list_difficulties,
        format("Masukkan tingkat kesulitan (mudah/sedang/sulit) > ", []),
        read(Difficulty),
        MapFile = 'generated_map.txt',
        generate_map(Size, Difficulty, MapFile),
        format("Peta acak berhasil dibuat: ~w (~wx~w, tingkat ~w)~n", [MapFile, Size, Size, Difficulty])
    ;
        format("Pilihan tidak dikenali, coba lagi.~n", []),
        ask_map_choice(MapFile)
    ).

% Membaca nama file sebagai BARIS MENTAH (bukan lewat read/1), supaya
% pemain bisa ketik nama file apa adanya (mis. map.txt) tanpa perlu
% tanda kutip atau titik di akhir -- kalau dibaca lewat read/1, titik
% di tengah nama file (map.txt) akan disalahartikan sebagai akhir
% perintah Prolog dan menyebabkan syntax error.
% REKURSIF: baris kosong dilewati (mis. sisa newline yang belum
% terbaca dari read(Choice) sebelumnya), sama seperti read_all_rows/2
% melewati baris kosong saat parsing peta.
read_filename(FileName) :-
    current_input(Stream),
    read_line_chars(Stream, Chars),
    ( Chars == end_of_file ->
        FileName = ''
    ; Chars == [] ->
        read_filename(FileName)
    ;
        atom_chars(FileName, Chars)
    ).

% Fail-driven loop: mencetak seluruh katalog peta yang tersedia.
list_known_maps :-
    known_map(File, Desc),
    format("  ~w - ~w~n", [File, Desc]),
    fail.
list_known_maps.

% Fail-driven loop: mencetak seluruh deskripsi tingkat kesulitan.
list_difficulties :-
    difficulty_description(Diff, Desc),
    format("  ~w - ~w~n", [Diff, Desc]),
    fail.
list_difficulties.

% --- Generator peta acak ---

% Menghasilkan peta acak Size x Size sesuai Difficulty, lalu menulisnya
% ke FileName dengan format yang sama seperti map.txt biasa.
generate_map(Size, Difficulty, FileName) :-
    retractall(gen_cell(_,_,_)),
    difficulty_params(Difficulty, NumPits, NumMonsters, NumTreasures, NumWeapons, MonsterSymbols),
    assertz(gen_cell(1, 1, 'S')),
    Budget is Size * Size * 10,
    place_fixed(Size, NumPits, Budget, 'P'),
    place_from_list(Size, NumMonsters, Budget, MonsterSymbols),
    place_from_list(Size, NumTreasures, Budget, ['G','E','R']),
    place_from_list(Size, NumWeapons, Budget, ['W','X']),
    ( Size >= 4 -> place_fixed(Size, 1, Budget, 'T') ; true ),
    write_generated_map(FileName, Size).

% REKURSIF: menghasilkan integer acak 1..N dari random/1 (GNU Prolog:
% float acak di [0,1)), dipakai berulang untuk tiap penempatan.
random_int(N, X) :-
    random(F),
    X is truncate(F * N) + 1.

% Memilih satu elemen acak dari sebuah list.
random_from_list(List, Elem) :-
    length(List, Len),
    random_int(Len, Idx),
    nth1_manual(Idx, List, Elem).

% Ambil elemen ke-N dari list (versi manual, index mulai dari 1).
nth1_manual(1, [X|_], X) :- !.
nth1_manual(N, [_|T], X) :-
    N > 1,
    N1 is N - 1,
    nth1_manual(N1, T, X).

% Menempatkan N simbol tetap (mis. pit) di posisi acak yang masih kosong.
% REKURSIF, dengan Budget sebagai batas percobaan (mencegah loop tanpa
% akhir jika peta terlalu kecil untuk jumlah item yang diminta).
place_fixed(_, 0, _, _) :- !.
place_fixed(_, _, 0, _) :- !.
place_fixed(Size, N, Budget, Symbol) :-
    N > 0, Budget > 0,
    random_int(Size, X),
    random_int(Size, Y),
    ( gen_cell(X, Y, _) ->
        Budget1 is Budget - 1,
        place_fixed(Size, N, Budget1, Symbol)
    ;
        assertz(gen_cell(X, Y, Symbol)),
        N1 is N - 1,
        place_fixed(Size, N1, Budget, Symbol)
    ).

% Menempatkan N simbol yang dipilih ACAK dari SymbolList tiap kali
% (dipakai untuk monster/treasure/senjata yang tipenya bervariasi).
place_from_list(_, 0, _, _) :- !.
place_from_list(_, _, 0, _) :- !.
place_from_list(Size, N, Budget, SymbolList) :-
    N > 0, Budget > 0,
    random_int(Size, X),
    random_int(Size, Y),
    ( gen_cell(X, Y, _) ->
        Budget1 is Budget - 1,
        place_from_list(Size, N, Budget1, SymbolList)
    ;
        random_from_list(SymbolList, Symbol),
        assertz(gen_cell(X, Y, Symbol)),
        N1 is N - 1,
        place_from_list(Size, N1, Budget, SymbolList)
    ).

% --- Penulisan hasil ke file (FILE PROCESSING) ---

% Menulis ukuran grid lalu seluruh isi gen_cell/3 ke file, baris per baris.
write_generated_map(FileName, Size) :-
    open(FileName, write, Stream),
    format(Stream, "~w ~w~n", [Size, Size]),
    write_rows(Stream, Size, 1),
    close(Stream).

% REKURSIF menulis tiap baris Y dari 1 sampai Size.
write_rows(_, Size, Y) :- Y > Size, !.
write_rows(Stream, Size, Y) :-
    write_row(Stream, Size, 1, Y),
    nl(Stream),
    Y1 is Y + 1,
    write_rows(Stream, Size, Y1).

% REKURSIF menulis tiap kolom X dalam satu baris; sel yang belum diisi
% gen_cell/3 ditulis sebagai '.' (ruang kosong).
write_row(_, Size, X, _) :- X > Size, !.
write_row(Stream, Size, X, Y) :-
    ( gen_cell(X, Y, Symbol) -> true ; Symbol = '.' ),
    write(Stream, Symbol),
    X1 is X + 1,
    write_row(Stream, Size, X1, Y).
