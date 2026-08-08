% =====================================================================
% main.pl - Entry point tunggal untuk PoC "Obor Terakhir" (GNU Prolog)
%
% Cara pakai (dari dalam folder poc/):
%   gprolog
%   | ?- ['main.pl'].
%
% Setelah itu tersedia:
%   run_demo.                 - demo otomatis (tanpa input manual)
%   start_game('map.txt').    - mode interaktif dengan peta tertentu
%   choose_map_and_start.     - pilih peta yang ada ATAU generate acak
%   run_all_tests.            - jalankan seluruh test suite
%   print_all_rooms.          - lihat isi peta (perlu load_map dulu)
%   show_leaderboard.         - lihat leaderboard (setelah pernah menang)
% =====================================================================

% GNU Prolog hanya menjamin eksekusi directive berupa goal sembarang
% (bukan deklarasi seperti dynamic/1) jika dibungkus initialization/1 --
% directive :- consult(...) / :- format(...) polos pernah "ignored"
% (lihat warning "maybe use initialization/1") pada sebagian jalur consult.
:- initialization(load_obor_terakhir).

% Memuat semua modul secara berurutan, lalu menampilkan banner.
load_obor_terakhir :-
    consult('src/world.pl'),
    consult('src/navigation.pl'),
    consult('src/actions.pl'),
    consult('src/scoring.pl'),
    consult('src/persistence.pl'),
    consult('src/mapgen.pl'),
    consult('src/game.pl'),
    consult('tests/test_suite.pl'),
    print_banner.

% Menampilkan judul program dan daftar command yang tersedia.
print_banner :-
    format("~n=====================================================~n", []),
    format("         O B O R   T E R A K H I R~n", []),
    format("       Bertahan di Kegelapan Gua~n", []),
    format("=====================================================~n", []),
    format("Perintah untuk mulai:~n", []),
    format("  choose_map_and_start.    - pilih peta yang ada ATAU generate acak (disarankan)~n", []),
    format("  start_game('map.txt').   - langsung main dengan peta bawaan~n", []),
    format("  run_demo.                - lihat demo otomatis tanpa mengetik command~n", []),
    format("~nPerintah lain:~n", []),
    format("  run_all_tests.           - jalankan seluruh test suite~n", []),
    format("  print_all_rooms.         - lihat isi peta (perlu load_map dulu)~n", []),
    format("  show_leaderboard.        - lihat leaderboard~n", []),
    format("~nSetelah masuk permainan, ketik help. kapan saja untuk lihat daftar command.~n~n", []).
