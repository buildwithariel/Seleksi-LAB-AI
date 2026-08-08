"""Proof of Concept: Data Center Network Topology Design via Local Search.

Menjalankan keempat varian Hill-Climbing, Simulated Annealing, dan Genetic
Algorithm pada instance yang sama, lalu mencetak state awal, state akhir, dan
nilai objective sepanjang pencarian.

    python main.py
"""
import os

import numpy as np

from topology import (
    generate_positions,
    random_initial_state,
    describe_state,
    objective,
)
from algorithms import (
    hill_climbing_steepest_ascent,
    hill_climbing_sideways,
    hill_climbing_stochastic,
    hill_climbing_random_restart,
    simulated_annealing,
    genetic_algorithm,
)

SEED = 42
N = 12
K_MAX = 4
WEIGHTS = dict(w_L=1.0, w_C=1.0, w_B=0.5, w_D=1.0)
PENALTY_BIG = 50.0

# Gambar disimpan di pic/ sebelah skrip ini, apa pun direktori kerja saat dijalankan.
PIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pic")


def section(title: str):
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


def main():
    rng = np.random.default_rng(SEED)
    positions = generate_positions(N, seed=SEED)
    A0 = random_initial_state(N, K_MAX, rng)

    section("INSTANCE PERMASALAHAN")
    print(f"N (jumlah node)        : {N}")
    print(f"K_max (port per node)  : {K_MAX}")
    print(f"Bobot objective        : {WEIGHTS}, penalty_disconnect={PENALTY_BIG}")

    section("INITIAL STATE (random spanning tree + edge tambahan)")
    print(describe_state(A0, positions, WEIGHTS, PENALTY_BIG))

    section("HILL-CLIMBING 1/4 (Steepest-Ascent / Basic)")
    hc_final, hc_history = hill_climbing_steepest_ascent(
        A0, K_MAX, positions, WEIGHTS, PENALTY_BIG, max_iter=300
    )
    print(f"Jumlah iterasi hingga local optimum: {len(hc_history) - 1}")
    print("State akhir:")
    print(describe_state(hc_final, positions, WEIGHTS, PENALTY_BIG))

    section("HILL-CLIMBING 2/4 (Sideways Move)")
    sw_final, sw_history = hill_climbing_sideways(
        A0, K_MAX, positions, WEIGHTS, PENALTY_BIG, max_iter=300, max_sideways=25
    )
    print(f"Jumlah iterasi: {len(sw_history) - 1} (termasuk langkah sideways)")
    print("State akhir:")
    print(describe_state(sw_final, positions, WEIGHTS, PENALTY_BIG))

    section("HILL-CLIMBING 3/4 (Stochastic)")
    st_rng = np.random.default_rng(SEED + 3)
    st_final, st_history = hill_climbing_stochastic(
        A0, K_MAX, positions, WEIGHTS, PENALTY_BIG, max_iter=300, rng=st_rng
    )
    print(f"Jumlah iterasi hingga local optimum: {len(st_history) - 1}")
    print("State akhir:")
    print(describe_state(st_final, positions, WEIGHTS, PENALTY_BIG))

    section("HILL-CLIMBING 4/4 (Random Restart)")
    rr_rng = np.random.default_rng(SEED + 4)
    rr_final, rr_history, rr_costs = hill_climbing_random_restart(
        N, K_MAX, positions, WEIGHTS, PENALTY_BIG,
        n_restarts=10, max_iter=300, rng=rr_rng,
    )
    print(f"Jumlah restart: {len(rr_costs)}")
    print("Cost akhir tiap restart : " + ", ".join(f"{c:.4f}" for c in rr_costs))
    print(f"Terbaik dari semua restart: {min(rr_costs):.4f} "
          f"(terburuk {max(rr_costs):.4f}) - sebaran ini memperlihatkan "
          f"beragamnya local optimum")
    print("State terbaik:")
    print(describe_state(rr_final, positions, WEIGHTS, PENALTY_BIG))

    section("SIMULATED ANNEALING")
    sa_rng = np.random.default_rng(SEED + 1)
    sa_final, sa_history = simulated_annealing(
        A0, K_MAX, positions, WEIGHTS, PENALTY_BIG,
        T0=10.0, cooling_rate=0.997, max_iter=3000, rng=sa_rng,
    )
    print(f"Jumlah iterasi: {len(sa_history) - 1}")
    print("State terbaik:")
    print(describe_state(sa_final, positions, WEIGHTS, PENALTY_BIG))

    section("GENETIC ALGORITHM")
    ga_rng = np.random.default_rng(SEED + 2)
    ga_final, ga_history = genetic_algorithm(
        N, K_MAX, positions, WEIGHTS, PENALTY_BIG,
        pop_size=40, generations=150, crossover_rate=0.8,
        mutation_rate=0.03, tournament_k=3, rng=ga_rng,
    )
    print(f"Jumlah generasi: {len(ga_history) - 1}")
    print("Individu terbaik:")
    print(describe_state(ga_final, positions, WEIGHTS, PENALTY_BIG))

    section("RINGKASAN PERBANDINGAN")
    init_cost = objective(A0, positions, WEIGHTS, PENALTY_BIG)["cost"]
    print(f"{'Algoritma':<32}{'Cost Awal':>12}{'Cost Akhir':>14}")
    print(f"{'HC - Steepest-Ascent':<32}{init_cost:>12.4f}{hc_history[-1]:>14.4f}")
    print(f"{'HC - Sideways Move':<32}{init_cost:>12.4f}{sw_history[-1]:>14.4f}")
    print(f"{'HC - Stochastic':<32}{init_cost:>12.4f}{st_history[-1]:>14.4f}")
    print(f"{'HC - Random Restart':<32}{'(acak)':>12}{min(rr_costs):>14.4f}")
    print(f"{'Simulated Annealing':<32}{init_cost:>12.4f}{min(sa_history):>14.4f}")
    print(f"{'Genetic Algorithm':<32}{'(acak)':>12}{ga_history[-1]:>14.4f}")
    print("\nCatatan: Random Restart & GA memulai dari state acaknya sendiri,")
    print("sehingga kolom 'Cost Awal' tidak berlaku untuk keduanya.")

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(13, 5))

        # Kiri: empat varian Hill-Climbing dari state awal yang sama, kecuali
        # Random Restart yang mengambil state awalnya sendiri.
        ax = axes[0]
        # Pada instance ini Sideways berimpit persis dengan Steepest-Ascent karena
        # tidak pernah menemui plateau, jadi digambar putus-putus agar garis di
        # bawahnya tetap terlihat.
        ax.plot(hc_history, marker="o", ms=4, lw=1.6, label="Steepest-Ascent")
        ax.plot(sw_history, ls="--", lw=2.6, alpha=0.75,
                label="Sideways Move (berimpit)")
        ax.plot(st_history, marker="^", ms=4, lw=1.6, label="Stochastic")
        ax.plot(rr_history, lw=1.8, label="Random Restart (best-so-far)")
        ax.set_xlabel("Iterasi")
        ax.set_ylabel("Objective cost (diminimalkan)")
        ax.set_title("Empat varian Hill-Climbing")
        ax.legend(fontsize=9)
        ax.grid(alpha=0.25)

        # Kanan: satu wakil tiap keluarga algoritma. Lintasan mentah SA melonjak
        # sampai ~9 di awal dan akan menggencet kurva lain, jadi ditampilkan samar
        # dengan envelope best-so-far di atasnya dan sumbu dipotong.
        ax = axes[1]
        sa_best = np.minimum.accumulate(sa_history)
        ax.plot(hc_history, lw=1.8, label="Hill-Climbing (Steepest-Ascent)")
        ax.plot(sa_history, lw=0.7, alpha=0.30, color="tab:orange",
                label="SA (cost saat ini)")
        ax.plot(sa_best, lw=1.8, color="tab:orange", label="SA (best-so-far)")
        ax.plot(ga_history, lw=1.8, color="tab:green",
                label="Genetic Algorithm (best-so-far)")
        ax.set_xlabel("Iterasi / Generasi")
        ax.set_ylabel("Objective cost (diminimalkan)")
        ax.set_title("Perbandingan antar algoritma")
        ax.set_ylim(1.85, 3.2)
        ax.legend(fontsize=8.5)
        ax.grid(alpha=0.25)

        fig.suptitle("Konvergensi Objective Function - Data Center Topology Local Search")
        fig.tight_layout()
        out_path = os.path.join(PIC_DIR, "objective_convergence.png")
        os.makedirs(PIC_DIR, exist_ok=True)
        fig.savefig(out_path, dpi=150)
        print(f"\n[Bonus] Grafik konvergensi objective disimpan ke: {out_path}")
    except ImportError:
        print("\n(matplotlib tidak tersedia, lewati grafik konvergensi)")


if __name__ == "__main__":
    main()
