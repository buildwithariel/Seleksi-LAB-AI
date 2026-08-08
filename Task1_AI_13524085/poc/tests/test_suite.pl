% =====================================================================
% test_suite.pl - Uji coba otomatis untuk memverifikasi PoC
%
% Jalankan dengan: ?- run_all_tests.
% Setiap test_*/0 adalah goal yang SUKSES bila perilaku sesuai harapan
% dan GAGAL (fail) bila tidak -- run_test/2 menangkap sukses/gagal itu
% dan mencetak [PASS]/[FAIL] untuk tiap kasus.
% =====================================================================

run_test(Name, Goal) :-
    ( catch(call(Goal), Error, (format("[ERROR] ~w -> ~w~n", [Name, Error]), fail)) ->
        format("[PASS] ~w~n", [Name])
    ;
        format("[FAIL] ~w~n", [Name])
    ).

run_all_tests :-
    format("~n=== MENJALANKAN TEST SUITE OBOR TERAKHIR ===~n~n", []),
    run_test(win_scenario_via_demo_commands, test_win),
    run_test(lose_masuk_jurang, test_lose_pit),
    run_test(lose_torch_habis, test_lose_torch),
    run_test(lose_kalah_dalam_pertarungan, test_lose_battle),
    run_test(shoot_mengenai_monster, test_shoot_hit),
    run_test(shoot_meleset_natural_fail, test_shoot_miss),
    run_test(grab_treasure_berhasil, test_grab_success),
    run_test(grab_gagal_natural_fail, test_grab_fail),
    run_test(grab_senjata_pedang, test_grab_weapon_pedang),
    run_test(grab_senjata_pistol_tambah_peluru, test_grab_weapon_pistol),
    run_test(equip_senjata_dimiliki, test_equip_success),
    run_test(equip_senjata_belum_dimiliki, test_equip_fail),
    run_test(battle_masuk_ruang_monster_memicu_battle, test_battle_triggered),
    run_test(battle_attack_mengalahkan_monster, test_battle_attack_kills),
    run_test(battle_pedang_melee_tanpa_biaya_amunisi, test_battle_melee_no_ammo_cost),
    run_test(battle_defend_potong_damage_setengah, test_defend_reduces_damage),
    run_test(battle_run_kembali_ke_ruang_sebelumnya, test_run_returns),
    run_test(climb_out_ditolak_natural_fail, test_climb_out_blocked),
    run_test(percept_breeze_dekat_pit, test_percept_breeze),
    run_test(percept_stench_dekat_monster, test_percept_stench),
    run_test(percept_glitter_di_treasure, test_percept_glitter),
    run_test(save_load_roundtrip, test_save_load),
    run_test(trapdoor_teleport_langsung, test_trapdoor_direct),
    run_test(masuk_ruang_monster_mati_aman_tanpa_battle, test_dead_monster_safe),
    run_test(battle_menolak_command_eksplorasi, test_battle_reject_explore),
    run_test(eksplorasi_menolak_command_battle, test_explore_reject_battle_cmds),
    run_test(kehabisan_amunisi_lalu_ganti_senjata_melee, test_ammo_then_switch),
    run_test(defend_tetap_bisa_mati_jika_hp_sangat_rendah, test_defend_death),
    run_test(quit_di_tengah_battle, test_quit_mid_battle),
    run_test(leaderboard_aman_saat_file_belum_ada, test_leaderboard_missing_file),
    run_test(semua_pojok_grid_menolak_keluar_batas, test_all_corners_reject),
    run_test(command_asal_di_mode_eksplorasi_ditolak_aman, test_unknown_explore_command),
    run_test(command_asal_di_mode_battle_ditolak_aman, test_unknown_battle_command),
    run_test(resume_gameplay_setelah_load_game, test_resume_after_load),
    run_test(grab_dua_kali_di_ruang_sama_gagal_alami, test_double_grab_same_room),
    run_test(shoot_ditolak_saat_amunisi_habis, test_shoot_no_ammo),
    run_test(pit_tetap_mati_instan_bukan_battle, test_pit_still_instant_death),
    run_test(generate_map_menghasilkan_peta_valid, test_generate_map_basic),
    run_test(generate_map_ukuran_berbeda, test_generate_map_different_size),
    run_test(random_int_selalu_dalam_rentang, test_random_int_range),
    run_test(help_tidak_mengubah_state_eksplorasi, test_help_no_state_change),
    run_test(help_tidak_mengubah_state_battle, test_help_battle_no_state_change),
    run_test(command_variabel_kosong_tidak_dianggap_quit, test_unbound_command_not_treated_as_quit),
    run_test(command_variabel_kosong_di_battle_tidak_dianggap_quit, test_unbound_command_in_battle_not_treated_as_quit),
    run_test(read_filename_lewati_baris_kosong_sisa, test_read_filename_skips_blank_line),
    run_test(read_filename_baca_nama_file_tanpa_kutip, test_read_filename_plain_name),
    run_test(show_map_tidak_mengubah_state, test_show_map_no_state_change),
    run_test(cell_symbol_sesuai_legenda_peta, test_cell_symbol_correctness),
    format("~n=== TEST SUITE SELESAI ===~n", []).

initial_state(state(EX,EY,selatan,25,3,0,30,[],[panah],panah,[])) :-
    entry(EX, EY).

% --- Skenario menang penuh (memakai demo_commands/1 dari game.pl) ---
test_win :-
    load_map('map.txt'),
    initial_state(S0),
    demo_commands(Commands),
    play_commands(S0, Commands, finished(win, _)).

% --- Kematian: masuk jurang ---
test_lose_pit :-
    load_map('tests/maps/map_pit.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], finished(lose(jatuh_ke_jurang), _)).

% --- Kematian: torch habis (state awal sengaja dibuat Torch=1) ---
test_lose_torch :-
    load_map('map.txt'),
    play_commands(state(1,1,selatan,1,3,0,30,[],[panah],panah,[]), [move(selatan)],
                  finished(lose(torch_habis), _)).

% --- Kematian: kalah dalam pertarungan (HP pemain sengaja 1) ---
% Memakai monster & posisi NYATA dari map.txt (laba_laba di (5,1)),
% supaya monster_hp/3 yang di-retract di dalam do_attack/2 benar-benar ada.
test_lose_battle :-
    load_map('map.txt'),
    monster_hp(5, 1, LabaHP),
    do_attack(battle(state(5,1,selatan,25,3,0,1,[],[panah],panah,[]), 5,1,laba_laba,LabaHP,4,1), NewState),
    NewState = finished(lose(tewas_dalam_pertarungan), _).

% --- Shoot mengenai monster pertama pada lintasan (CUT), dari jarak jauh ---
test_shoot_hit :-
    load_map('map.txt'),
    trace_arrow(3,1,1,0,HitX,HitY),
    HitX == 5, HitY == 1.

% --- Shoot ke arah kosong: gagal alami (FAIL) ---
test_shoot_miss :-
    load_map('map.txt'),
    \+ trace_arrow(1,1,0,-1,_,_).

test_grab_success :-
    load_map('map.txt'),
    can_grab(3,2).

% --- FAIL alami: tidak ada treasure di entry room ---
test_grab_fail :-
    load_map('map.txt'),
    \+ can_grab(1,1).

% --- Grab senjata pedang di (1,4) ---
test_grab_weapon_pedang :-
    load_map('map.txt'),
    do_grab(state(1,4,selatan,25,3,0,30,[],[panah],panah,[]), NewState),
    NewState = state(1,4,selatan,25,3,0,30,[],[pedang,panah],panah,[grab]).

% --- Grab senjata pistol di (2,5), menambah 2 bullet ---
test_grab_weapon_pistol :-
    load_map('map.txt'),
    do_grab(state(2,5,selatan,25,3,0,30,[],[panah],panah,[]), NewState),
    NewState = state(2,5,selatan,25,3,2,30,[],[pistol,panah],panah,[grab]).

test_equip_success :-
    do_equip(pedang, state(1,1,selatan,25,3,0,30,[],[pedang,panah],panah,[]), NewState),
    NewState = state(1,1,selatan,25,3,0,30,[],[pedang,panah],pedang,[]).

% --- equip senjata yang belum dimiliki: Equipped tidak berubah ---
test_equip_fail :-
    do_equip(pistol, state(1,1,selatan,25,3,0,30,[],[panah],panah,[]), NewState),
    NewState = state(1,1,selatan,25,3,0,30,[],[panah],panah,[]).

% --- Masuk ruang monster hidup memicu battle(...), bukan mati instan ---
test_battle_triggered :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], Result),
    Result = battle(_, _, _, kelelawar, 15, _, _).

% --- Attack berulang kali mengalahkan monster lemah (kelelawar) ---
% panah adalah senjata ranged -> tiap attack ikut memakan 1 Arrow,
% persis seperti shoot/1 di luar battle (konsistensi biaya amunisi).
test_battle_attack_kills :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan), attack, attack, attack], Final),
    Final = state(1,2,selatan,_,0,0,24,[],[panah],panah,_).

% --- Attack dengan pedang (melee) TIDAK memakan Arrow/Bullets ---
% Pemain sudah membawa pedang sejak awal (unit test langsung, tidak
% bergantung pickup di map) supaya fokus menguji biaya amunisi saja.
test_battle_melee_no_ammo_cost :-
    load_map('tests/maps/map_monster.txt'),
    entry(EX, EY),
    S0 = state(EX,EY,selatan,25,3,0,30,[],[pedang,panah],panah,[]),
    play_commands(S0, [move(selatan), equip(pedang), attack], Result),
    Result = battle(state(1,2,selatan,_,3,0,_,[],[pedang,panah],pedang,_), 1,2,kelelawar,_,1,1).

% --- Defend memotong damage serangan balik monster setengah ---
test_defend_reduces_damage :-
    load_map('map.txt'),
    monster_base_stats(troll, THP, _, _),
    do_defend(battle(state(1,1,selatan,25,3,0,30,[],[panah],panah,[]), 5,5,troll,THP,1,1), NewState),
    NewState = battle(state(1,1,selatan,25,3,0,26,[],[panah],panah,[defend]), 5,5,troll,THP,1,1).

% --- Run selalu berhasil, kembali ke posisi sebelum battle dimulai ---
test_run_returns :-
    do_run(battle(state(5,1,selatan,20,3,0,20,[],[panah],panah,[]), 5,1,laba_laba,10,4,1), NewState),
    NewState = state(4,1,selatan,20,3,0,20,[],[panah],panah,[run]).

% --- FAIL alami: bukan di entry room ---
test_climb_out_blocked :-
    load_map('map.txt'),
    \+ at_entry(3,2).

test_percept_breeze :-
    load_map('map.txt'),
    percept(1,3,P),
    memberchk(breeze, P).

test_percept_stench :-
    load_map('map.txt'),
    percept(4,1,P),
    memberchk(stench, P).

test_percept_glitter :-
    load_map('map.txt'),
    percept(3,2,P),
    memberchk(glitter, P).

% --- Save/load state (FILE PROCESSING round-trip) ---
test_save_load :-
    S = state(2,3,timur,20,1,1,25,[gold,gem],[panah,pistol],pistol,[grab,move(timur)]),
    save_game('tests/tmp_save_test.pl', S),
    load_game('tests/tmp_save_test.pl', S2),
    S == S2.

% =====================================================================
% Edge case tambahan (verifikasi menyeluruh sebelum submission)
% =====================================================================

% --- Trapdoor langsung: jalan ke (4,4), auto-teleport ke entry ---
test_trapdoor_direct :-
    load_map('map.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan), move(timur), move(timur), move(timur), move(selatan), move(selatan)], Result),
    Result = state(1,1,_,19,3,0,30,[],[panah],panah,_).

% --- Ruang monster yang SUDAH mati aman dimasuki, tidak memicu battle lagi ---
test_dead_monster_safe :-
    load_map('map.txt'),
    retract(monster(5,1,laba_laba,alive)),
    assertz(monster(5,1,laba_laba,dead)),
    handle_arrival(5,1,utara,20,3,0,30,[],[panah],panah,[],5,2,Result),
    Result = state(5,1,utara,20,3,0,30,[],[panah],panah,[]).

% --- Saat battle, command eksplorasi (move/grab/climb_out) ditolak, state tak berubah ---
test_battle_reject_explore :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], Battle0),
    Battle0 = battle(_,_,_,_,_,_,_),
    battle_apply_command(move(utara), Battle0, R1), R1 == Battle0,
    battle_apply_command(grab, Battle0, R2), R2 == Battle0,
    battle_apply_command(climb_out, Battle0, R3), R3 == Battle0.

% --- Saat eksplorasi (bukan battle), command attack/defend/run ditolak ---
test_explore_reject_battle_cmds :-
    load_map('map.txt'),
    initial_state(S0),
    apply_command(attack, S0, R1), R1 == S0,
    apply_command(defend, S0, R2), R2 == S0,
    apply_command(run, S0, R3), R3 == S0.

% --- Kehabisan amunisi panah di tengah battle, attack ditolak, lalu ganti pedang berhasil ---
test_ammo_then_switch :-
    load_map('tests/maps/map_monster.txt'),
    entry(EX,EY),
    S0 = state(EX,EY,selatan,25,1,0,30,[],[pedang,panah],panah,[]),
    play_commands(S0, [move(selatan), attack], R1),
    R1 = battle(state(_,_,_,_,0,0,_,_,_,panah,_),_,_,kelelawar,_,_,_),
    battle_apply_command(attack, R1, R2),
    R2 == R1,
    battle_apply_command(equip(pedang), R1, R3),
    battle_apply_command(attack, R3, R4),
    R4 \== R1.

% --- Defend TETAP bisa berujung mati jika HP sangat rendah (bukan cuma attack) ---
test_defend_death :-
    load_map('map.txt'),
    monster_hp(5,1,LHP),
    do_defend(battle(state(5,1,selatan,20,3,0,2,[],[panah],panah,[]),5,1,laba_laba,LHP,4,1), NewState),
    NewState = finished(lose(tewas_dalam_pertarungan), _).

% --- Quit di tengah battle ---
test_quit_mid_battle :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan), quit], finished(quit, _)).

% --- show_leaderboard aman walau leaderboard.txt belum ada ---
test_leaderboard_missing_file :-
    show_leaderboard.

% --- Semua pojok grid menolak bergerak keluar batas ---
test_all_corners_reject :-
    load_map('map.txt'),
    do_move(barat, state(1,1,selatan,25,3,0,30,[],[panah],panah,[]), R1), R1 = state(1,1,_,_,_,_,_,_,_,_,_),
    do_move(utara, state(1,1,selatan,25,3,0,30,[],[panah],panah,[]), R2), R2 = state(1,1,_,_,_,_,_,_,_,_,_),
    do_move(timur, state(5,1,selatan,25,3,0,30,[],[panah],panah,[]), R3), R3 = state(5,1,_,_,_,_,_,_,_,_,_),
    do_move(utara, state(5,1,selatan,25,3,0,30,[],[panah],panah,[]), R4), R4 = state(5,1,_,_,_,_,_,_,_,_,_),
    do_move(selatan, state(5,5,selatan,25,3,0,30,[],[panah],panah,[]), R5), R5 = state(5,5,_,_,_,_,_,_,_,_,_),
    do_move(timur, state(5,5,selatan,25,3,0,30,[],[panah],panah,[]), R6), R6 = state(5,5,_,_,_,_,_,_,_,_,_).

% --- Command tidak dikenal di mode eksplorasi ditangani aman, tidak crash ---
test_unknown_explore_command :-
    load_map('map.txt'),
    initial_state(S0),
    apply_command(foobar(123), S0, R),
    R == S0.

% --- Command tidak dikenal di mode battle ditangani aman, tidak crash ---
test_unknown_battle_command :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], B0),
    battle_apply_command(foobar, B0, R),
    R == B0.

% --- Setelah load_game, state hasil load benar2 bisa dipakai lanjut main (bukan cuma sama struktur) ---
test_resume_after_load :-
    load_map('map.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan), move(timur)], S2),
    save_game('tests/tmp_edge_save.pl', S2),
    load_game('tests/tmp_edge_save.pl', S3),
    do_move(timur, S3, S4),
    S4 = state(3,2,timur,_,_,_,_,_,_,_,_).

% --- Grab dua kali di ruang yang sama (treasure sudah diambil): gagal alami kedua kalinya ---
test_double_grab_same_room :-
    load_map('map.txt'),
    do_grab(state(3,2,selatan,25,3,0,30,[],[panah],panah,[]), R1),
    R1 = state(3,2,selatan,25,3,0,30,[gold],[panah],panah,[grab]),
    \+ can_grab(3,2),
    do_grab(R1, R2),
    R2 = state(3,2,selatan,25,3,0,30,[gold],[panah],panah,[grab]).

% --- shoot ditolak saat amunisi senjata aktif habis ---
test_shoot_no_ammo :-
    load_map('map.txt'),
    do_shoot(timur, state(3,1,selatan,25,0,0,30,[],[panah],panah,[]), R),
    R == state(3,1,selatan,25,0,0,30,[],[panah],panah,[]).

% --- Pit tetap mati instan (tidak berubah jadi battle seperti monster) ---
test_pit_still_instant_death :-
    load_map('tests/maps/map_pit.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], finished(lose(jatuh_ke_jurang), _)).

% =====================================================================
% Peta Prosedural (Bonus B2) - generate_map/3
% =====================================================================

% --- Peta acak yang di-generate valid: bisa dimuat ulang, jumlah tiap
% elemen sesuai difficulty_params(sedang,...), entry selalu di (1,1) ---
test_generate_map_basic :-
    generate_map(6, sedang, 'tests/tmp_gen_map.txt'),
    load_map('tests/tmp_gen_map.txt'),
    grid_size(6),
    entry(1,1),
    findall(_, pit(_,_), Pits), length(Pits, 4),
    findall(_, monster(_,_,_,alive), Monsters), length(Monsters, 4),
    findall(_, treasure(_,_,_), Treasures), length(Treasures, 3),
    findall(_, weapon_item(_,_,_), Weapons), length(Weapons, 2).

% --- Ukuran grid lain (8x8) & difficulty lain (sulit) juga valid ---
test_generate_map_different_size :-
    generate_map(8, sulit, 'tests/tmp_gen_map2.txt'),
    load_map('tests/tmp_gen_map2.txt'),
    grid_size(8),
    entry(1,1),
    findall(_, pit(_,_), Pits), length(Pits, 6),
    findall(_, monster(_,_,_,alive), Monsters), length(Monsters, 5).

% --- random_int/2 selalu menghasilkan integer dalam rentang [1,N] ---
test_random_int_range :-
    random_int(10, X1), X1 >= 1, X1 =< 10,
    random_int(3, X2), X2 >= 1, X2 =< 3,
    random_int(100, X3), X3 >= 1, X3 =< 100.

% =====================================================================
% Command help. dan penjagaan terhadap salah ketik (var(Command))
% =====================================================================

% --- help. di mode eksplorasi: gratis, state benar-benar tidak berubah ---
test_help_no_state_change :-
    load_map('map.txt'),
    initial_state(S0),
    apply_command(help, S0, R),
    R == S0.

% --- help. saat battle: gratis, battle state tidak berubah ---
test_help_battle_no_state_change :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], B0),
    B0 = battle(_,_,_,_,_,_,_),
    battle_apply_command(help, B0, R),
    R == B0.

% --- Command berupa variabel kosong (mis. akibat salah ketik HELP.
% huruf besar, yang di Prolog berarti variabel bukan atom) TIDAK boleh
% dianggap end_of_file/quit. Ini bug nyata yang sempat kejadian:
% variabel kosong otomatis "cocok" dengan pola end_of_file kalau tidak
% ada penjagaan var(Command) di klausa paling awal. ---
test_unbound_command_not_treated_as_quit :-
    load_map('map.txt'),
    initial_state(S0),
    apply_command(_, S0, R),
    R == S0.

test_unbound_command_in_battle_not_treated_as_quit :-
    load_map('tests/maps/map_monster.txt'),
    initial_state(S0),
    play_commands(S0, [move(selatan)], B0),
    battle_apply_command(_, B0, R),
    R == B0.

% =====================================================================
% read_filename/1 (input nama file peta tanpa kutip/titik)
% =====================================================================

% --- Baris kosong sisa (mis. dari read(Choice) sebelumnya) harus
% dilewati, bukan malah dibaca sebagai nama file kosong. Ini bug nyata
% yang sempat kejadian: nama file jadi '' lalu open/3 error. ---
test_read_filename_skips_blank_line :-
    open('tests/tmp_filename_input.txt', write, WStream),
    nl(WStream),
    format(WStream, "map.txt~n", []),
    close(WStream),
    open('tests/tmp_filename_input.txt', read, RStream),
    set_input(RStream),
    read_filename(FileName),
    set_input(user_input),
    close(RStream),
    FileName == 'map.txt'.

% --- Nama file biasa (tanpa baris kosong di depan) juga terbaca benar. ---
test_read_filename_plain_name :-
    open('tests/tmp_filename_input2.txt', write, WStream),
    format(WStream, "generated_map.txt~n", []),
    close(WStream),
    open('tests/tmp_filename_input2.txt', read, RStream),
    set_input(RStream),
    read_filename(FileName),
    set_input(user_input),
    close(RStream),
    FileName == 'generated_map.txt'.

% =====================================================================
% show_map: grid visual peta gua
% =====================================================================

% --- show_map. gratis, tidak mengubah state sama sekali ---
test_show_map_no_state_change :-
    load_map('map.txt'),
    initial_state(S0),
    apply_command(show_map, S0, R),
    R == S0.

% --- cell_symbol/5 menampilkan simbol yang sesuai dengan legenda
% map.txt untuk tiap jenis isi ruangan, dan '@' begitu posisi cocok
% dengan posisi pemain (menang lebih dulu daripada simbol lain, CUT). ---
test_cell_symbol_correctness :-
    load_map('map.txt'),
    cell_symbol(1,1,9,9,'S'),
    cell_symbol(1,1,1,1,'@'),
    cell_symbol(2,3,9,9,'P'),
    cell_symbol(5,1,9,9,'L'),
    cell_symbol(3,2,9,9,'G'),
    cell_symbol(1,4,9,9,'X'),
    cell_symbol(2,5,9,9,'W'),
    cell_symbol(4,4,9,9,'T'),
    cell_symbol(2,2,9,9,'.').
