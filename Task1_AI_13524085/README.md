# Obor Terakhir
### Bertahan di Kegelapan Gua (Task #1 Seleksi Laboratorium Intelegensi Buatan)

Sebuah *text-based dungeon crawler* yang ditulis penuh dalam **GNU Prolog**, dibuat sebagai proof of concept untuk spesifikasi Tugas Besar Logika Komputasional. Pemain menjelajahi gua berbentuk grid yang dimuat dari file eksternal, mengandalkan **persepsi tersembunyi** (bukan pandangan langsung, terinspirasi Wumpus World) untuk menghindari bahaya, mengumpulkan harta & senjata, **bertarung** melawan 5 tipe monster, dan kembali keluar dengan selamat.

Proyek ini sekaligus jadi bukti bahwa keenam konsep wajib pemrograman logika (**rekursi, list, cut, fail, loop, file processing**) bisa muncul secara alami dari rancangan game yang koheren, bukan ditempel dipaksakan.

## Installing / Getting started

Kebutuhan satu-satunya: [GNU Prolog](http://www.gprolog.org/) 1.5+.

```bash
gprolog --version
```

Kalau belum terinstal, unduh installer dari situs resmi di atas sesuai OS Anda.

Clone/download repository ini, lalu jalankan `gprolog` dari dalam folder `poc/` (semua path pada kode ini relatif terhadap `poc/`, jadi jangan dari `src/` atau folder lain):

```bash
cd poc
gprolog
```

Di dalam prompt `| ?-` GNU Prolog (ketik satu baris, Enter, tunggu hasilnya):

```prolog
['main.pl'].
```

Setelah itu tersedia beberapa mode:

**a) Test suite** (paling disarankan untuk verifikasi cepat): memuat seluruh modul lalu menjalankan 48 skenario uji otomatis, mencetak `[PASS]`/`[FAIL]` untuk masing-masing:

```prolog
run_all_tests.
```

**b) Demo otomatis**: melihat alur permainan lengkap (eksplorasi, battle, menang) tanpa mengetik command manual:

```prolog
run_demo.
```

**c) Mode interaktif**: main sendiri dengan peta bawaan, lalu ketik command satu-satu (`move(selatan).`, `grab.`, `attack.`, dst.; lihat [Fitur](#features) untuk daftar lengkap; ketik `help.` kapan saja untuk bantuan):

```prolog
start_game('map.txt').
```

**d) Leaderboard & debug map:**

```prolog
show_leaderboard.     % setelah minimal 1x menang
print_all_rooms.      % daftar teks isi peta (perlu load_map/1 atau start_game/1 dulu)
show_bag.              % lihat isi tas, bisa dipanggil kapan saja termasuk saat battle
show_map.               % lihat peta dalam bentuk grid visual (lihat contoh di bawah)
```

**e) Pilih peta: file yang ada ATAU generate acak** (Bonus B2: Peta Prosedural):

```prolog
choose_map_and_start.
```

Akan muncul menu untuk memilih peta yang sudah ada (dengan katalog & deskripsi singkat) atau men-generate peta baru (ukuran grid dan tingkat kesulitan `mudah`/`sedang`/`sulit` diketik sendiri). **Hasil eksekusi nyata**:

```
=== PILIH SUMBER PETA ===
1. Gunakan file peta yang sudah ada
2. Generate peta acak (Peta Prosedural)
Pilihan (1/2) > 2.
Masukkan ukuran grid N (mis. 6) > 8.
Masukkan tingkat kesulitan (mudah/sedang/sulit) > sedang.
Peta acak berhasil dibuat: generated_map.txt (8x8, tingkat sedang)
Peta berhasil dimuat: grid 8x8.
```

**f) Lihat peta visual (grid)**: `show_map.` mencetak peta sebagai grid ASCII bergaris, posisi pemain ditandai `@`, aman dipanggil kapan saja tanpa mengubah state. **Hasil eksekusi nyata**:

```
| ?- show_map.

=== PETA GUA (5x5) ===
+---+---+---+---+---+
| S | . | . | . | L |
+---+---+---+---+---+
| . | . | @ | . | . |
+---+---+---+---+---+
| . | P | . | . | . |
+---+---+---+---+---+
| X | . | . | T | . |
+---+---+---+---+---+
| . | W | . | . | R |
+---+---+---+---+---+
Legenda: @ Anda | S entry | P pit | T trapdoor | . kosong
Monster: K kelelawar, L laba-laba, J goblin, C troll, N naga
Treasure: G gold, E gem, R relic | Senjata: W pistol, X pedang
true.
```

## Developing

Struktur repository:

```
.
├── README.md                # dokumen ini
└── poc/                      # proof of concept, source code GNU Prolog
    ├── main.pl                 # entry point, consult file ini
    ├── src/                    # modul-modul game
    │   ├── world.pl              # fakta dunia + pemuatan map.txt (File Processing)
    │   ├── navigation.pl          # arah, adjacency (List), percept
    │   ├── actions.pl             # move/grab/equip/shoot/climb_out + battle: attack/defend/run
    │   ├── scoring.pl             # perhitungan skor
    │   ├── persistence.pl         # save/load state, game_log.txt, leaderboard.txt
    │   ├── mapgen.pl               # Bonus B2: generate_map/3 + menu choose_map_and_start/0
    │   └── game.pl                 # game loop (eksplorasi + battle), dispatcher command, mode demo
    ├── tests/                  # test suite otomatis (48 skenario) + peta uji khusus
    │   ├── test_suite.pl
    │   └── maps/                  # peta mini untuk skenario kematian/battle deterministik
    └── map.txt                 # peta utama untuk demo & mode interaktif
```

Untuk mengubah kode: edit file di `poc/src/*.pl` sesuai modulnya, lalu konsultasikan ulang `['main.pl'].` di GNU Prolog (fakta dunia di-reset otomatis tiap `load_map/1` dipanggil, jadi tidak perlu keluar dari sesi).

## Building

Tidak ada langkah build. GNU Prolog dijalankan secara interpreted lewat `consult`/`initialization`. Jika ingin dikompilasi jadi executable standalone (opsional, tidak wajib untuk submission), GNU Prolog menyediakan `gplc`:

```bash
gplc -o obor_terakhir main.pl
./obor_terakhir
```

## Features

- **Eksplorasi berbasis persepsi tersembunyi**: `breeze` (pit di tetangga), `stench` (monster hidup di tetangga), `glitter` (treasure di ruang ini), `draft` (trapdoor di tetangga)
- **5 tipe monster** dengan stat HP/ATK/DEF berbeda: kelelawar, laba-laba, goblin, troll, naga
- **3 senjata** dengan mekanik berbeda: panah & pistol (ranged, bisa `shoot` dari jauh), pedang (melee, hanya saat battle)
- **Sistem pertarungan** attack/defend/run: masuk ruang monster hidup memicu battle sungguhan, bukan mati instan
- **Peta visual grid**: `show_map.` mencetak peta sebagai tabel ASCII bergaris (posisi pemain `@`), bisa dipanggil kapan saja tanpa mengubah state
- **Bantuan bawaan**: `help.` menampilkan seluruh command yang tersedia kapan saja, gratis tanpa mengubah state
- **Manajemen sumber daya**: Torch (batas langkah), HP (nyawa), Arrow & Bullet (amunisi per senjata)
- **Peta dari file eksternal**: tidak di-hardcode, format grid karakter sederhana, ukuran N x N bebas (bukan cuma 5x5 bawaan)
- **Peta Prosedural**: `choose_map_and_start.` untuk memilih antara peta yang sudah ada atau generate peta acak (ukuran & tingkat kesulitan bebas)
- **Save/load** progres permainan ke file
- **Leaderboard** persisten antar sesi (skor kemenangan, terurut)
- **Test suite otomatis**: 48 skenario, `run_all_tests.` untuk verifikasi cepat

## Configuration

Peta dikonfigurasi lewat file teks (`poc/map.txt` secara default), format:

```
5 5
S...L
..G..
.P...
X..T.
.W..R
```

Baris pertama = ukuran grid (diasumsikan persegi, hanya angka pertama yang dipakai). Simbol: `.` kosong, `S` entry, `P` pit, `G`/`E`/`R` treasure (gold/gem/relic), `T` trapdoor (selalu kembali ke entry), `W` pistol, `X` pedang, `K`/`L`/`J`/`C`/`N` = kelelawar/laba-laba/goblin/troll/naga.

Koordinat `(X, Y)`: `X` = kolom (1..N, kiri ke kanan), `Y` = baris (1..N, atas ke bawah, sesuai urutan baris di file). `utara` mengurangi `Y`, `selatan` menambah `Y`, `timur` menambah `X`, `barat` mengurangi `X`.

Nilai awal pemain (Torch=25, HP=30, Arrow=3, Bullet=0) saat ini adalah konstanta di `start_game/1`, bukan dikonfigurasi lewat file. Peta khusus di `poc/tests/maps/` (grid 2x2 minimal) dipakai supaya skenario kematian/battle dapat diuji deterministik, terpisah dari `map.txt` utama.

## Pemetaan Konsep Wajib ke Kode

| Konsep | Predicate (file) |
|---|---|
| **Rekursi** | `parse_row/3`, `read_all_rows/2`, `read_line_chars/2`, `chars_to_number/3` (`world.pl`); `adjacent_list/4`, `neighbor_percepts/2` (`navigation.pl`); `trace_arrow/6` (`actions.pl`); `treasure_score/2`, `action_cost/2` (`scoring.pl`); `sort_scores_desc/2` (`persistence.pl`); `play_commands/3`, `demo_loop/2` (`game.pl`); `place_fixed/4`, `place_from_list/4`, `write_rows/3`, `write_row/4` (`mapgen.pl`) |
| **List** | `Inventory`, `Weapons`, `ActionLog` pada `state/11`; list tetangga (`adjacent_list/3`); list persepsi (`percept/3`); list karakter baris file (`parse_row/3`); `MonsterSymbols`/`SymbolList` pada `random_from_list/2` (`mapgen.pl`) |
| **Cut** | `valid_position/2`, `room_percept_contribution/3` (`navigation.pl`); `handle_arrival/13` prioritas pit > monster (battle) > torch (`actions.pl`); `trace_arrow/6` & `do_attack/2` berhenti begitu target/kondisi pertama ditemukan; `process_cell/3` satu jenis simbol per klausa (`world.pl`); `ask_map_choice/1` menu (`mapgen.pl`) |
| **Fail** | `resolve_trapdoors/0`, `print_all_rooms/0`: idiom `Goal, aksi, fail.` (fail-driven loop); `can_grab/2`, `can_pickup_weapon/2`, `at_entry/2`: gagal alami saat kondisi tak terpenuhi, dipakai langsung sebagai guard di `do_grab/2` (`actions.pl`) dan dibuktikan oleh `test_grab_fail`, `test_climb_out_blocked`, `test_shoot_miss`, `test_equip_fail`; `place_fixed/4`/`place_from_list/4` mundur (retry) via cabang if-then-else saat sel sudah terisi (`mapgen.pl`) |
| **Loop** | `game_loop/1` (dua mode: eksplorasi & battle, rekursi ekor), `demo_loop/2`, `play_commands/3` (`game.pl`); `resolve_trapdoors/0`, `print_all_rooms/0` (fail-driven loop); `ask_map_choice/1` mengulang (rekursi ekor) selama pilihan menu tidak valid (`mapgen.pl`) |
| **File Processing** | `load_map/1` (baca `map.txt` karakter-per-karakter via `get_char/2`, bukan `consult` fakta jadi, `world.pl`); `save_game/2`/`load_game/2`, `write_log/3`, `update_leaderboard/1`/`show_leaderboard/0` (`persistence.pl`); `write_generated_map/2` menulis peta hasil generate ke file baru yang lalu dimuat ulang lewat `load_map/1` yang sama (`mapgen.pl`) |

## Contributing

Proyek ini dikerjakan sebagai tugas seleksi individual, bukan proyek open source aktif.

Developer: **Ariel Cornelius Sitorus**, NIM 132524085

## Links

- GNU Prolog resmi: [http://www.gprolog.org/](http://www.gprolog.org/)
- Inspirasi konsep (Wumpus World): Russell, S. & Norvig, P., *Artificial Intelligence: A Modern Approach*
