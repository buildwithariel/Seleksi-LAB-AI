% =====================================================================
% actions.pl - Aksi pemain: move, grab, shoot, equip, climb_out,
% serta aksi battle: attack, defend, run.
%
% State eksplorasi: state(X,Y,Facing,Torch,Arrow,Bullets,HP,Inventory,
%                          Weapons,Equipped,ActionLog)
% State battle:     battle(ExploreState, MonsterX, MonsterY, Type,
%                           MonsterHP, PrevX, PrevY)
% =====================================================================

% do_move: pindah satu petak searah Dir kalau masih dalam batas grid,
% torch berkurang 1, lalu diteruskan ke handle_arrival/13 untuk dicek
% ada bahaya apa tidak di ruang tujuan.
do_move(Dir, state(X,Y,_,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), NewState) :-
    offset(Dir, DX, DY),
    !,
    NX is X + DX, NY is Y + DY,
    ( valid_position(NX, NY) ->
        NewTorch is Torch - 1,
        NewLog = [move(Dir)|Log],
        handle_arrival(NX, NY, Dir, NewTorch, Arrow, Bullets, HP, Inv, Weapons, Equipped,
                        NewLog, X, Y, NewState)
    ;
        format("Tidak bisa bergerak ke arah ~w, di luar batas gua.~n", [Dir]),
        NewState = state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log)
    ).
do_move(Dir, State, State) :-
    format("Arah tidak dikenal: ~w~n", [Dir]).

% CUT berantai: prioritas begitu tiba di ruang baru --
% pit (mati) > monster hidup (mulai battle) > torch habis (mati) >
% trapdoor (dipindah) > aman.
handle_arrival(X, Y, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, Log, _, _,
               finished(lose(jatuh_ke_jurang),
                        state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log))) :-
    pit(X, Y), !.
handle_arrival(X, Y, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, Log, PrevX, PrevY,
               battle(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log),
                      X, Y, Type, MHP, PrevX, PrevY)) :-
    monster(X, Y, Type, alive), !,
    monster_hp(X, Y, MHP),
    format("~nSeekor ~w menghadang! Pertarungan dimulai.~n", [Type]).
handle_arrival(X, Y, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, Log, _, _,
               finished(lose(torch_habis),
                        state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log))) :-
    Torch =< 0, !.
handle_arrival(X, Y, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, Log, _, _, NewState) :-
    trapdoor(X, Y, TX, TY),
    !,
    format("Anda terjatuh ke jebakan dan berpindah ke (~w,~w)!~n", [TX, TY]),
    NewState = state(TX, TY, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, Log).
handle_arrival(X, Y, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, Log, _, _,
               state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log)).

% do_grab: ambil treasure ATAU senjata di ruang saat ini (if-then-else
% membungkus can_grab/2 & can_pickup_weapon/2 yang gagal alami).
do_grab(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), NewState) :-
    ( can_grab(X, Y), treasure(X, Y, Type) ->
        retract(treasure(X, Y, Type)),
        format("Anda menemukan ~w! Ditambahkan ke inventory.~n", [Type]),
        NewState = state(X,Y,Dir,Torch,Arrow,Bullets,HP,[Type|Inv],Weapons,Equipped,[grab|Log])
    ; can_pickup_weapon(X, Y), weapon_item(X, Y, Weapon) ->
        retract(weapon_item(X, Y, Weapon)),
        ( memberchk(Weapon, Weapons) ->
            NewWeapons = Weapons,
            format("Anda menemukan ~w lagi (sudah dimiliki).~n", [Weapon])
        ;
            NewWeapons = [Weapon|Weapons],
            format("Anda menemukan senjata baru: ~w! Ditambahkan ke persenjataan.~n", [Weapon])
        ),
        ( Weapon == pistol ->
            NewBullets is Bullets + 2,
            format("Anda mendapat 2 peluru tambahan.~n", [])
        ;
            NewBullets = Bullets
        ),
        NewState = state(X,Y,Dir,Torch,Arrow,NewBullets,HP,Inv,NewWeapons,Equipped,[grab|Log])
    ;
        format("Tidak ada apa pun di ruangan ini untuk diambil.~n", []),
        NewState = state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log)
    ).

% do_equip: ganti senjata aktif (bebas dipakai saat eksplorasi maupun battle).
do_equip(Weapon, state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), NewState) :-
    ( memberchk(Weapon, Weapons) ->
        format("Senjata aktif diganti ke: ~w.~n", [Weapon]),
        NewState = state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Weapon,Log)
    ;
        format("Anda belum memiliki senjata ~w.~n", [Weapon]),
        NewState = state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log)
    ).

% do_shoot: menembak dari jarak jauh dengan senjata ranged yang sedang
% aktif (panah/pistol). Pedang (melee) ditolak. REKURSIF via trace_arrow/6,
% CUT begitu monster hidup pertama ditemukan pada lintasan.
do_shoot(Dir, state(X,Y,_,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), NewState) :-
    weapon_stats(Equipped, Damage, ranged),
    ( Equipped == panah -> Arrow > 0 ; Bullets > 0 ),
    !,
    ( Equipped == panah ->
        NewArrow is Arrow - 1, NewBullets = Bullets
    ;
        NewBullets is Bullets - 1, NewArrow = Arrow
    ),
    offset(Dir, DX, DY),
    ( trace_arrow(X, Y, DX, DY, HitX, HitY) ->
        monster(HitX, HitY, Type, alive),
        monster_hp(HitX, HitY, MHP),
        NewMHP is MHP - Damage,
        retract(monster_hp(HitX, HitY, MHP)),
        assertz(monster_hp(HitX, HitY, NewMHP)),
        ( NewMHP =< 0 ->
            retract(monster(HitX, HitY, Type, alive)),
            assertz(monster(HitX, HitY, Type, dead)),
            format("Anda mendengar teriakan mengerikan! Monster di (~w,~w) tewas.~n", [HitX, HitY])
        ;
            format("Serangan mengenai ~w di (~w,~w)! Sisa HP: ~w~n", [Type, HitX, HitY, NewMHP])
        )
    ;
        format("Serangan melesat menembus kegelapan... tidak mengenai apa pun.~n", [])
    ),
    NewState = state(X,Y,Dir,Torch,NewArrow,NewBullets,HP,Inv,Weapons,Equipped,[shoot(Dir)|Log]).
% Senjata aktif pedang (melee) tidak bisa menembak dari jauh.
do_shoot(_, state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,pedang,Log),
         state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,pedang,Log)) :-
    !,
    format("Pedang tidak bisa menembak dari jarak jauh. Dekati musuh untuk bertarung.~n", []).
% Senjata ranged tapi amunisinya sudah habis.
do_shoot(_, State, State) :-
    format("Anda kehabisan amunisi untuk senjata ini!~n", []).

% Menyusuri lintasan panah/peluru satu petak demi satu petak sampai
% ketemu monster hidup (CUT, langsung berhenti) atau keluar batas grid
% (gagal alami, artinya meleset).
trace_arrow(X, Y, DX, DY, HitX, HitY) :-
    NX is X + DX, NY is Y + DY,
    valid_position(NX, NY),
    ( monster(NX, NY, _, alive) ->
        HitX = NX, HitY = NY, !
    ;
        trace_arrow(NX, NY, DX, DY, HitX, HitY)
    ).

% do_climb_out: cuma berhasil kalau posisi pemain sama dengan entry
% room. Kalau berhasil, permainan langsung berakhir menang.
do_climb_out(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log), NewState) :-
    ( at_entry(X, Y) ->
        NewState = finished(win,
            state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,[climb_out|Log]))
    ;
        format("Anda harus berada di entry room untuk keluar. Posisi saat ini: (~w,~w).~n", [X,Y]),
        NewState = state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log)
    ).

% =====================================================================
% Aksi battle: attack, defend, run
% =====================================================================

% do_attack: damage ke monster = max(1, WeaponDamage - MonsterDEF).
% Jika monster mati, kembali ke mode eksplorasi. Jika belum, monster
% membalas: damage ke pemain = MonsterATK. Cek kematian pemain (CUT).
do_attack(battle(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log),
                  MX, MY, Type, MHP, PrevX, PrevY),
          NewState) :-
    weapon_stats(Equipped, WDamage, Kind),
    ( Kind == ranged -> ( Equipped == panah -> Arrow > 0 ; Bullets > 0 ) ; true ),
    !,
    ( Kind == ranged ->
        ( Equipped == panah -> NewArrow is Arrow - 1, NewBullets = Bullets
        ; NewBullets is Bullets - 1, NewArrow = Arrow
        )
    ;
        NewArrow = Arrow, NewBullets = Bullets
    ),
    monster_base_stats(Type, _, MATK, MDEF),
    DamageToMonster is max(1, WDamage - MDEF),
    NewMHP is MHP - DamageToMonster,
    NewLog = [attack(Equipped)|Log],
    format("Anda menyerang dengan ~w! Damage: ~w.~n", [Equipped, DamageToMonster]),
    ( NewMHP =< 0 ->
        retract(monster(MX, MY, Type, alive)),
        assertz(monster(MX, MY, Type, dead)),
        retractall(monster_hp(MX, MY, _)),
        format("~w berhasil dikalahkan!~n", [Type]),
        NewState = state(X,Y,Dir,Torch,NewArrow,NewBullets,HP,Inv,Weapons,Equipped,NewLog)
    ;
        retract(monster_hp(MX, MY, MHP)),
        assertz(monster_hp(MX, MY, NewMHP)),
        format("Sisa HP ~w: ~w~n", [Type, NewMHP]),
        NewHP is HP - MATK,
        DisplayHP is max(0, NewHP),
        format("~w menyerang balik! Damage: ~w. Sisa HP Anda: ~w~n", [Type, MATK, DisplayHP]),
        ( NewHP =< 0 ->
            NewState = finished(lose(tewas_dalam_pertarungan),
                state(X,Y,Dir,Torch,NewArrow,NewBullets,NewHP,Inv,Weapons,Equipped,NewLog))
        ;
            NewState = battle(state(X,Y,Dir,Torch,NewArrow,NewBullets,NewHP,Inv,Weapons,Equipped,NewLog),
                               MX, MY, Type, NewMHP, PrevX, PrevY)
        )
    ).
% Senjata ranged aktif kehabisan amunisi saat mau attack di battle.
do_attack(BState, BState) :-
    format("Anda kehabisan amunisi untuk senjata ini! Coba ganti senjata, defend, atau run.~n", []).

% do_defend: pemain tidak menyerang giliran ini, tapi damage yang
% diterima dari serangan balik monster dipotong setengah.
do_defend(battle(state(X,Y,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log),
                  MX, MY, Type, MHP, PrevX, PrevY),
          NewState) :-
    monster_base_stats(Type, _, MATK, _),
    ReducedDamage is max(1, MATK // 2),
    NewHP is HP - ReducedDamage,
    NewLog = [defend|Log],
    DisplayHP is max(0, NewHP),
    format("Anda bersiap bertahan! Damage dari ~w dipotong setengah.~n", [Type]),
    format("~w menyerang! Damage: ~w. Sisa HP Anda: ~w~n", [Type, ReducedDamage, DisplayHP]),
    ( NewHP =< 0 ->
        NewState = finished(lose(tewas_dalam_pertarungan),
            state(X,Y,Dir,Torch,Arrow,Bullets,NewHP,Inv,Weapons,Equipped,NewLog))
    ;
        NewState = battle(state(X,Y,Dir,Torch,Arrow,Bullets,NewHP,Inv,Weapons,Equipped,NewLog),
                           MX, MY, Type, MHP, PrevX, PrevY)
    ).

% do_run: selalu berhasil, mundur ke ruang sebelum battle dimulai.
% HP monster yang sudah berkurang tetap tersimpan di monster_hp/3 untuk
% pertemuan berikutnya (fakta dinamis, tidak direset).
do_run(battle(state(_,_,Dir,Torch,Arrow,Bullets,HP,Inv,Weapons,Equipped,Log),
              _, _, _, _, PrevX, PrevY),
       NewState) :-
    format("Anda kabur dari pertarungan!~n", []),
    NewLog = [run|Log],
    NewState = state(PrevX, PrevY, Dir, Torch, Arrow, Bullets, HP, Inv, Weapons, Equipped, NewLog).
