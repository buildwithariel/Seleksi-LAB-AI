% =====================================================================
% scoring.pl - Perhitungan skor akhir permainan
% =====================================================================

% Skor akhir = nilai treasure dikurangi biaya aksi, ditambah/dikurangi
% bonus/penalti tergantung hasil akhirnya (menang/kalah/berhenti).
compute_score(Inventory, Log, win, Score) :-
    !,
    treasure_score(Inventory, TS),
    action_cost(Log, AC),
    Score is TS - AC + 500.
compute_score(Inventory, Log, lose(_), Score) :-
    !,
    treasure_score(Inventory, TS),
    action_cost(Log, AC),
    Score is TS - AC - 1000.
compute_score(Inventory, Log, quit, Score) :-
    treasure_score(Inventory, TS),
    action_cost(Log, AC),
    Score is TS - AC.

% REKURSI menjumlahkan nilai seluruh treasure dalam Inventory (LIST).
treasure_score([], 0).
treasure_score([Type|Rest], Score) :-
    treasure_value(Type, Value),
    treasure_score(Rest, RestScore),
    Score is Value + RestScore.

% REKURSI menjumlahkan biaya aksi dari ActionLog (LIST), CUT tiap tipe aksi.
action_cost([], 0).
action_cost([move(_)|Rest], Cost) :-
    !,
    action_cost(Rest, RestCost),
    Cost is RestCost + 1.
action_cost([shoot(_)|Rest], Cost) :-
    !,
    action_cost(Rest, RestCost),
    Cost is RestCost + 10.
action_cost([_|Rest], Cost) :-
    action_cost(Rest, Cost).
