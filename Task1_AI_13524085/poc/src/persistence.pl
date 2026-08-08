% =====================================================================
% persistence.pl - FILE PROCESSING: save/load state, log, leaderboard
% =====================================================================

% Menyimpan seluruh state permainan ke file sebagai satu term Prolog
% biasa (writeq + titik di akhir), supaya bisa dibaca lagi apa adanya.
save_game(FileName, State) :-
    open(FileName, write, Stream),
    writeq(Stream, State),
    write(Stream, '.'),
    nl(Stream),
    close(Stream).

% Membaca kembali state yang sudah disimpan save_game/2.
load_game(FileName, State) :-
    open(FileName, read, Stream),
    read(Stream, State),
    close(Stream).

% Menulis riwayat aksi (ActionLog) dan hasil akhir ke game_log.txt.
% Mode append supaya log sesi-sesi sebelumnya tidak tertimpa.
write_log(Log, Result, Score) :-
    open('game_log.txt', append, Stream),
    format(Stream, "=== Sesi Permainan ===~n", []),
    reverse(Log, OrderedLog),
    write_log_lines(Stream, OrderedLog),
    format(Stream, "Status akhir: ~w~n", [Result]),
    format(Stream, "Skor akhir: ~w~n~n", [Score]),
    close(Stream).

% Menulis tiap aksi ke satu baris, REKURSIF sampai list Log habis.
write_log_lines(_, []).
write_log_lines(Stream, [Action|Rest]) :-
    format(Stream, "~w.~n", [Action]),
    write_log_lines(Stream, Rest).

% Menambahkan satu baris skor ke leaderboard.txt (dipanggil cuma
% saat menang, lihat finish_game/2 di game.pl).
update_leaderboard(Score) :-
    open('leaderboard.txt', append, Stream),
    format(Stream, "~w~n", [Score]),
    close(Stream).

% Menampilkan 5 skor tertinggi dari leaderboard.txt. Dibungkus catch/3
% supaya tetap aman kalau file belum pernah dibuat sama sekali.
show_leaderboard :-
    catch(read_all_scores('leaderboard.txt', Scores), _, Scores = []),
    sort_scores_desc(Scores, Sorted),
    format("~n=== TOP 5 SKOR ===~n", []),
    top_n(Sorted, 5, Top),
    print_scores(Top).

% Membaca seluruh isi leaderboard.txt jadi satu list angka.
read_all_scores(FileName, Scores) :-
    open(FileName, read, Stream),
    read_score_lines(Stream, Scores),
    close(Stream).

% Membaca file skor baris per baris, REKURSIF, tiap baris diubah jadi
% angka lewat chars_to_number/2 (dari world.pl).
read_score_lines(Stream, Scores) :-
    read_line_chars(Stream, Line),
    ( Line == end_of_file ->
        Scores = []
    ; Line == [] ->
        read_score_lines(Stream, Scores)
    ;
        chars_to_number(Line, Score),
        Scores = [Score|Rest],
        read_score_lines(Stream, Rest)
    ).

% REKURSI: insertion sort menurun, dipakai untuk mengurutkan leaderboard.
sort_scores_desc([], []).
sort_scores_desc([H|T], Sorted) :-
    sort_scores_desc(T, SortedT),
    insert_sorted_desc(H, SortedT, Sorted).

% Menyisipkan satu skor ke posisi yang benar dalam list yang sudah terurut.
insert_sorted_desc(X, [], [X]).
insert_sorted_desc(X, [H|T], [X,H|T]) :- X >= H, !.
insert_sorted_desc(X, [H|T], [H|Rest]) :- insert_sorted_desc(X, T, Rest).

% Mengambil N elemen pertama dari sebuah list (buat ambil top-5 skor).
top_n(_, 0, []) :- !.
top_n([], _, []) :- !.
top_n([H|T], N, [H|Rest]) :- N1 is N - 1, top_n(T, N1, Rest).

% Mencetak tiap skor di satu baris terpisah.
print_scores([]).
print_scores([S|Rest]) :- format("~w~n", [S]), print_scores(Rest).
