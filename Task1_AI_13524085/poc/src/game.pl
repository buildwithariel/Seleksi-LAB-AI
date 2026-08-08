% =====================================================================
% game.pl - Orkestrasi permainan: game loop eksplorasi + battle loop
% (LOOP via rekursi ekor), dispatcher command, dan mode demo otomatis.
% =====================================================================

% Entry point mode interaktif: memuat peta lalu mulai game loop dengan
% state awal (Torch=25, HP=30, Arrow=3, senjata awal panah).
start_game(MapFile) :-
    load_map(MapFile),
    grid_size(N),
    format("Peta berhasil dimuat: grid ~wx~w.~n", [N, N]),
    entry(EX, EY),
    format("Selamat datang di Obor Terakhir! Torch: 25, HP: 30, Senjata awal: panah (Arrow: 3).~n", []),
    format("Ketik help. kapan saja untuk lihat daftar command.~n", []),
    game_loop(state(EX, EY, selatan, 25, 3, 0, 30, [], [panah], panah, [])).

% --- Game loop utama (LOOP lewat rekursi ekor) ---
% Tiga klausa dicek berurutan: game sudah selesai, sedang battle, atau
% masih eksplorasi biasa. Tiap iterasi membaca satu command lalu
% memanggil game_loop lagi dengan state yang sudah diperbarui.
game_loop(finished(Result, State)) :-
    !,
    finish_game(Result, State).
game_loop(battle(ExploreState, MX, MY, Type, MHP, PrevX, PrevY)) :-
    !,
    ExploreState = state(_,_,_,_,_,_,HP,_,_,Equipped,_),
    format("~n=== PERTARUNGAN vs ~w ===~n", [Type]),
    format("HP Musuh: ~w | HP Anda: ~w | Senjata aktif: ~w~n", [MHP, HP, Equipped]),
    format("Command: attack. / defend. / run. / equip(Senjata). / show_bag. / show_map. / help.~n", []),
    format("Masukkan command > ", []),
    read(Command),
    battle_apply_command(Command, battle(ExploreState, MX, MY, Type, MHP, PrevX, PrevY), NewState),
    game_loop(NewState).
game_loop(State) :-
    State = state(X, Y, _, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, _),
    format("~n--- Posisi: (~w,~w) | Torch: ~w | HP: ~w | Senjata: ~w ---~n",
           [X, Y, Torch, HP, Equipped]),
    format("Arrow: ~w | Bullets: ~w | Weapons: ~w | Inventory: ~w~n",
           [Arrow, Bullets, Weapons, Inv]),
    percept(X, Y, P),
    format("Persepsi: ~w~n", [P]),
    format("Masukkan command > ", []),
    read(Command),
    apply_command(Command, State, NewState),
    game_loop(NewState).

% --- Dispatcher command mode eksplorasi ---
% Meneruskan tiap command ke predicate aksi yang sesuai di actions.pl.
% attack/defend/run sengaja ditolak di sini karena cuma valid saat battle.
%
% CUT PALING AWAL: kalau Command ternyata variabel kosong (bukan atom
% biasa -- ini terjadi kalau pemain tidak sengaja ketik huruf besar,
% mis. HELP. dibaca Prolog sebagai variabel, bukan atom help), tolak
% lebih dulu di sini. Tanpa penjagaan ini, variabel kosong akan otomatis
% "cocok" dengan pola end_of_file di klausa berikutnya dan diam-diam
% menganggap pemain mau quit -- padahal cuma salah ketik.
apply_command(Command, State, State) :-
    var(Command),
    !,
    format("Command tidak dikenali (huruf pertama command harus huruf kecil). Coba lagi.~n", []).
apply_command(end_of_file, State, finished(quit, State)) :- !.
apply_command(quit, State, finished(quit, State)) :- !.
apply_command(move(Dir), State, NewState) :- !, do_move(Dir, State, NewState).
apply_command(grab, State, NewState) :- !, do_grab(State, NewState).
apply_command(shoot(Dir), State, NewState) :- !, do_shoot(Dir, State, NewState).
apply_command(equip(Weapon), State, NewState) :- !, do_equip(Weapon, State, NewState).
apply_command(climb_out, State, NewState) :- !, do_climb_out(State, NewState).
apply_command(save_game(File), State, NewState) :-
    !,
    save_game(File, State),
    format("Progres disimpan ke ~w.~n", [File]),
    NewState = State.
apply_command(print_map, State, NewState) :-
    !,
    print_all_rooms,
    NewState = State.
apply_command(show_bag, State, NewState) :-
    !,
    do_show_bag(State),
    NewState = State.
apply_command(show_map, State, NewState) :-
    !,
    do_show_map(State),
    NewState = State.
% help. gratis: cuma menampilkan bantuan, tidak menyentuh state sama
% sekali (torch/HP/amunisi/posisi semuanya tetap).
apply_command(help, State, State) :- !, game_help.
apply_command(attack, State, State) :- !, format("Anda tidak sedang bertarung.~n", []).
apply_command(defend, State, State) :- !, format("Anda tidak sedang bertarung.~n", []).
apply_command(run, State, State) :- !, format("Anda tidak sedang bertarung.~n", []).
apply_command(_, State, State) :-
    format("Command tidak dikenali. Ketik help. untuk lihat daftar command.~n", []).

% --- Dispatcher command mode battle ---
% Cuma menerima attack/defend/run/equip/show_bag/help/quit. Command
% eksplorasi (move/grab/dst.) otomatis ditolak lewat klausa terakhir.
% CUT PALING AWAL: penjagaan yang sama seperti apply_command/3 di atas,
% supaya variabel kosong (salah ketik huruf besar) tidak nyangkut ke
% klausa quit di bawahnya.
battle_apply_command(Command, BState, BState) :-
    var(Command),
    !,
    format("Command tidak dikenali (huruf pertama command harus huruf kecil). Coba lagi.~n", []).
battle_apply_command(attack, BState, NewState) :- !, do_attack(BState, NewState).
battle_apply_command(defend, BState, NewState) :- !, do_defend(BState, NewState).
battle_apply_command(run, BState, NewState) :- !, do_run(BState, NewState).
battle_apply_command(help, BState, BState) :- !, game_help.
battle_apply_command(equip(Weapon), battle(ES,MX,MY,Type,MHP,PX,PY), battle(NewES,MX,MY,Type,MHP,PX,PY)) :-
    !,
    do_equip(Weapon, ES, NewES).
battle_apply_command(show_bag, battle(ES,MX,MY,Type,MHP,PX,PY), battle(ES,MX,MY,Type,MHP,PX,PY)) :-
    !,
    do_show_bag(ES).
battle_apply_command(show_map, battle(ES,MX,MY,Type,MHP,PX,PY), battle(ES,MX,MY,Type,MHP,PX,PY)) :-
    !,
    do_show_map(ES).
battle_apply_command(quit, battle(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), _,_,_,_,_,_),
                      finished(quit, state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log))) :- !.
battle_apply_command(end_of_file, battle(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), _,_,_,_,_,_),
                      finished(quit, state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log))) :- !.
battle_apply_command(_, BState, BState) :-
    format("Sedang bertarung! Command tersedia: attack. / defend. / run. / equip(Senjata). / show_bag. / show_map. / help. / quit.~n", []).

% Menampilkan isi tas: torch, HP, senjata (dimiliki + aktif), amunisi,
% dan treasure. Bisa dipanggil kapan saja, termasuk saat battle.
do_show_bag(state(_,_,_,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,_)) :-
    format("~n=== ISI TAS ===~n", []),
    format("Torch: ~w | HP: ~w~n", [Torch, HP]),
    format("Senjata dimiliki: ~w (aktif: ~w)~n", [Weapons, Equipped]),
    format("Arrow: ~w | Bullets: ~w~n", [Arrow, Bullets]),
    format("Treasure: ~w~n", [Inv]).

% =====================================================================
% show_map: peta gua digambar sebagai GRID kotak-kotak (bukan daftar
% teks polos seperti print_all_rooms), posisi pemain ditandai '@'.
% Simbolnya sama persis dengan legenda map.txt supaya tidak perlu
% belajar simbol baru.
% =====================================================================

do_show_map(state(PX,PY,_,_,_,_,_,_,_,_,_)) :-
    grid_size(N),
    format("~n=== PETA GUA (~wx~w) ===~n", [N, N]),
    print_map_border(N),
    print_map_rows(N, 1, PX, PY),
    format("Legenda: @ Anda | S entry | P pit | T trapdoor | . kosong~n", []),
    format("Monster: K kelelawar, L laba-laba, J goblin, C troll, N naga~n", []),
    format("Treasure: G gold, E gem, R relic | Senjata: W pistol, X pedang~n", []).

% REKURSIF menggambar garis pembatas atas/bawah tiap baris grid,
% mis. "+---+---+---+" untuk grid berukuran 3.
print_map_border(N) :-
    format("+", []),
    print_map_border_cells(N),
    nl.

print_map_border_cells(0) :- !.
print_map_border_cells(N) :-
    N > 0,
    format("---+", []),
    N1 is N - 1,
    print_map_border_cells(N1).

% REKURSIF menggambar tiap baris grid dari Y=1 sampai Y=N, diselingi
% garis pembatas setelah tiap baris.
print_map_rows(N, Y, _, _) :- Y > N, !.
print_map_rows(N, Y, PX, PY) :-
    format("|", []),
    print_map_row_cells(N, 1, Y, PX, PY),
    nl,
    print_map_border(N),
    Y1 is Y + 1,
    print_map_rows(N, Y1, PX, PY).

% REKURSIF menggambar tiap sel dalam satu baris dari X=1 sampai X=N.
print_map_row_cells(N, X, _, _, _) :- X > N, !.
print_map_row_cells(N, X, Y, PX, PY) :-
    cell_symbol(X, Y, PX, PY, Symbol),
    format(" ~w |", [Symbol]),
    X1 is X + 1,
    print_map_row_cells(N, X1, Y, PX, PY).

% Menentukan simbol yang ditampilkan untuk satu sel: posisi pemain
% paling diutamakan (CUT), baru entry/pit/monster/treasure/senjata/
% trapdoor, dan '.' kalau kosong. Ruang berisi monster yang sudah mati
% dianggap aman dan ditampilkan sebagai '.' (bukan simbol monsternya).
cell_symbol(X, Y, PX, PY, '@') :- X == PX, Y == PY, !.
cell_symbol(X, Y, _, _, 'S') :- entry(X, Y), !.
cell_symbol(X, Y, _, _, 'P') :- pit(X, Y), !.
cell_symbol(X, Y, _, _, Symbol) :- monster(X, Y, Type, alive), !, monster_display_symbol(Type, Symbol).
cell_symbol(X, Y, _, _, Symbol) :- treasure(X, Y, Type), !, treasure_display_symbol(Type, Symbol).
cell_symbol(X, Y, _, _, Symbol) :- weapon_item(X, Y, Weapon), !, weapon_display_symbol(Weapon, Symbol).
cell_symbol(X, Y, _, _, 'T') :- trapdoor(X, Y, _, _), !.
cell_symbol(_, _, _, _, '.').

monster_display_symbol(kelelawar, 'K').
monster_display_symbol(laba_laba, 'L').
monster_display_symbol(goblin, 'J').
monster_display_symbol(troll, 'C').
monster_display_symbol(naga, 'N').

treasure_display_symbol(gold, 'G').
treasure_display_symbol(gem, 'E').
treasure_display_symbol(relic, 'R').

weapon_display_symbol(pistol, 'W').
weapon_display_symbol(pedang, 'X').

% Menampilkan daftar seluruh command yang tersedia. Command gratis:
% tidak memakan torch/amunisi/HP dan tidak mengubah state permainan
% sedikit pun -- aman dipanggil kapan saja, termasuk saat battle.
game_help :-
    format("~n=== BANTUAN OBOR TERAKHIR ===~n", []),
    format("Command Eksplorasi:~n", []),
    format("  move(utara/selatan/timur/barat). - bergerak 1 petak~n", []),
    format("  grab.                            - ambil treasure/senjata di ruang ini~n", []),
    format("  shoot(Arah).                     - tembak senjata ranged aktif ke suatu arah~n", []),
    format("  equip(panah/pistol/pedang).      - ganti senjata aktif~n", []),
    format("  climb_out.                       - keluar gua (harus di entry room)~n", []),
    format("  save_game(NamaFile).             - simpan progres ke file~n", []),
    format("  show_bag.                        - lihat isi tas~n", []),
    format("  show_map.                        - lihat peta gua dalam bentuk grid visual~n", []),
    format("  print_map.                       - lihat seluruh isi gua (daftar teks, debug)~n", []),
    format("~nCommand Battle (cuma bisa dipakai saat sedang bertarung):~n", []),
    format("  attack.  - serang pakai senjata aktif~n", []),
    format("  defend.  - bertahan, damage balasan monster dipotong setengah~n", []),
    format("  run.     - kabur dari battle, selalu berhasil~n", []),
    format("~nCommand Umum:~n", []),
    format("  help.    - tampilkan bantuan ini (gratis, tidak mengubah apa pun)~n", []),
    format("  quit.    - berhenti main kapan saja~n~n", []).

% Menghitung skor akhir, mencetak ringkasan, lalu menyimpan hasilnya
% ke game_log.txt dan leaderboard.txt (khusus kalau menang).
finish_game(Result, state(X,Y,_,_,_,_,HP,Inv,_,_,Log)) :-
    compute_score(Inv, Log, Result, Score),
    describe_result(Result),
    format("Skor akhir: ~w~n", [Score]),
    write_log(Log, Result, Score),
    ( Result == win -> update_leaderboard(Score) ; true ),
    format("Statistik akhir - Posisi: (~w,~w), HP: ~w, Inventory: ~w~n", [X, Y, HP, Inv]).

% Pesan penutup sesuai hasil akhir permainan.
describe_result(win) :- !, format("~nAnda berhasil keluar dari gua dengan selamat!~n", []).
describe_result(lose(Reason)) :- !, format("~nGame Over. Anda kalah. Penyebab: ~w~n", [Reason]).
describe_result(quit) :- format("~nPermainan dihentikan oleh pemain.~n", []).

% Contoh idiom FAIL-DRIVEN LOOP klasik: `Goal, aksi, fail.` diakhiri
% klausa basis yang selalu sukses, dipisah per jenis fakta.
print_all_rooms :-
    format("~n=== DAFTAR ISI GUA ===~n", []),
    fail.
print_all_rooms :-
    entry(X, Y),
    format("Room (~w,~w): entry~n", [X, Y]),
    fail.
print_all_rooms :-
    pit(X, Y),
    format("Room (~w,~w): pit~n", [X, Y]),
    fail.
print_all_rooms :-
    monster(X, Y, Type, Status),
    format("Room (~w,~w): monster(~w,~w)~n", [X, Y, Type, Status]),
    fail.
print_all_rooms :-
    treasure(X, Y, Type),
    format("Room (~w,~w): treasure(~w)~n", [X, Y, Type]),
    fail.
print_all_rooms :-
    weapon_item(X, Y, Weapon),
    format("Room (~w,~w): weapon(~w)~n", [X, Y, Weapon]),
    fail.
print_all_rooms :-
    trapdoor(X, Y, TX, TY),
    format("Room (~w,~w): trapdoor -> (~w,~w)~n", [X, Y, TX, TY]),
    fail.
print_all_rooms.

% Menjalankan LIST command berurutan tanpa cetak status tiap langkah
% (dipakai oleh test suite), REKURSIF, berhenti begitu game selesai,
% dan mengarahkan ke dispatcher yang sesuai (eksplorasi vs battle).
play_commands(finished(Result, State), _, finished(Result, State)) :- !.
play_commands(battle(ES,MX,MY,Type,MHP,PX,PY), [Cmd|Rest], Final) :-
    !,
    battle_apply_command(Cmd, battle(ES,MX,MY,Type,MHP,PX,PY), NewState),
    play_commands(NewState, Rest, Final).
play_commands(State, [], State).
play_commands(State, [Cmd|Rest], Final) :-
    apply_command(Cmd, State, NewState),
    play_commands(NewState, Rest, Final).

% --- Mode demo otomatis (tanpa input manual) ---

% Skenario contoh: ambil gold, ambil senjata pistol+pedang, ambil
% relic, lalu bertarung melawan monster di (5,1) sebelum climb_out.
demo_commands([
    move(selatan), move(timur), move(timur), grab,
    move(selatan), move(selatan), move(selatan),
    move(barat), grab,
    move(barat),
    move(utara), grab,
    move(selatan),
    move(timur), move(timur), move(timur), move(timur), grab,
    move(utara), move(utara), move(utara), move(utara),
    equip(pedang), attack, attack,
    equip(pistol), attack, attack,
    move(barat), move(barat), move(barat), move(barat),
    climb_out
]).

% Menjalankan demo_commands/1 di atas satu per satu sambil mencetak
% tiap langkahnya, memakai peta bawaan map.txt.
run_demo :-
    load_map('map.txt'),
    entry(EX, EY),
    format("~n=== DEMO OTOMATIS: OBOR TERAKHIR ===~n", []),
    demo_commands(Commands),
    demo_loop(state(EX, EY, selatan, 25, 3, 0, 30, [], [panah], panah, []), Commands).

% Sama seperti game_loop/1, tapi command diambil dari list (bukan
% read/1) dan tetap mencetak status tiap langkah untuk ditonton.
demo_loop(finished(Result, State), _) :-
    !,
    finish_game(Result, State).
demo_loop(battle(ExploreState, MX, MY, Type, MHP, PrevX, PrevY), [Command|Rest]) :-
    !,
    ExploreState = state(_,_,_,_,_,_,HP,_,_,Equipped,_),
    format("~n=== PERTARUNGAN vs ~w === HP Musuh: ~w | HP Anda: ~w | Senjata: ~w~n",
           [Type, MHP, HP, Equipped]),
    format(">> Command: ~w~n", [Command]),
    battle_apply_command(Command, battle(ExploreState, MX, MY, Type, MHP, PrevX, PrevY), NewState),
    demo_loop(NewState, Rest).
demo_loop(State, []) :-
    !,
    State = state(X,Y,_,Torch,_,_,HP,Inv,_,_,_),
    format("~nDemo selesai (command habis). Posisi: (~w,~w), Torch: ~w, HP: ~w, Inventory: ~w~n",
           [X, Y, Torch, HP, Inv]).
demo_loop(State, [Command|Rest]) :-
    State = state(X, Y, _, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, _),
    format("~n--- Posisi: (~w,~w) | Torch: ~w | HP: ~w | Senjata: ~w ---~n",
           [X, Y, Torch, HP, Equipped]),
    format("Arrow: ~w | Bullets: ~w | Weapons: ~w | Inventory: ~w~n",
           [Arrow, Bullets, Weapons, Inv]),
    percept(X, Y, P),
    format("Persepsi: ~w~n", [P]),
    format(">> Command: ~w~n", [Command]),
    apply_command(Command, State, NewState),
    demo_loop(NewState, Rest).
