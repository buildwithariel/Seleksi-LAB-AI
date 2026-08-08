"""Algoritma local search untuk Data Center Network Topology Design: empat varian
Hill-Climbing (steepest-ascent, sideways move, stochastic, random restart),
Simulated Annealing, dan Genetic Algorithm.

Seluruhnya MEMINIMALKAN topology.objective(...)['cost'].
"""
from __future__ import annotations

import numpy as np

from topology import (
    get_all_neighbors,
    get_random_neighbor,
    random_initial_state,
    objective,
    degrees,
)


# Hill-Climbing varian Steepest-Ascent (Basic)

def hill_climbing_steepest_ascent(A0: np.ndarray, k_max: int, positions: np.ndarray,
                                   weights: dict = None, penalty_big: float = 50.0,
                                   max_iter: int = 300):
    current = A0.copy()
    current_cost = objective(current, positions, weights, penalty_big)["cost"]
    history = [current_cost]

    for _ in range(max_iter):
        neighbors = get_all_neighbors(current, k_max)
        best_nb, best_cost = None, current_cost
        for nb in neighbors:
            c = objective(nb, positions, weights, penalty_big)["cost"]
            if c < best_cost:
                best_cost, best_nb = c, nb
        if best_nb is None:
            break  # local optimum
        current, current_cost = best_nb, best_cost
        history.append(current_cost)

    return current, history


# Hill-Climbing varian Sideways Move

def hill_climbing_sideways(A0: np.ndarray, k_max: int, positions: np.ndarray,
                            weights: dict = None, penalty_big: float = 50.0,
                            max_iter: int = 300, max_sideways: int = 25):
    """Steepest-ascent yang juga menerima neighbor dengan cost sama.

    Steepest-ascent biasa berhenti begitu tidak ada perbaikan ketat, padahal di
    plateau itu berarti menyerah saat dataran datarnya masih mungkin menuju
    tempat yang lebih baik. max_sideways membatasi langkah mendatar berturut-turut
    supaya pencarian tidak berputar selamanya.
    """
    current = A0.copy()
    current_cost = objective(current, positions, weights, penalty_big)["cost"]
    history = [current_cost]
    sideways_used = 0

    for _ in range(max_iter):
        best_nb, best_cost = None, np.inf
        for nb in get_all_neighbors(current, k_max):
            c = objective(nb, positions, weights, penalty_big)["cost"]
            if c < best_cost:
                best_cost, best_nb = c, nb

        if best_nb is None:
            break

        if best_cost < current_cost - 1e-12:          # benar-benar membaik
            sideways_used = 0
        elif abs(best_cost - current_cost) <= 1e-12:  # datar, pakai jatah sideways
            if sideways_used >= max_sideways:
                break
            sideways_used += 1
        else:                                          # tersisa yang lebih buruk
            break

        current, current_cost = best_nb, best_cost
        history.append(current_cost)

    return current, history


# Hill-Climbing varian Stochastic

def hill_climbing_stochastic(A0: np.ndarray, k_max: int, positions: np.ndarray,
                              weights: dict = None, penalty_big: float = 50.0,
                              max_iter: int = 300, rng: np.random.Generator = None):
    """Memilih secara acak di antara neighbor yang memperbaiki cost.

    Steepest-ascent bersifat deterministik, jadi dari state yang sama ia selalu
    menempuh jalur yang sama menuju local optimum yang sama. Memilih sembarang
    neighbor yang membaik membuat lintasannya bervariasi antar run dan berpeluang
    mendarat di basin yang berbeda.
    """
    rng = rng or np.random.default_rng()
    current = A0.copy()
    current_cost = objective(current, positions, weights, penalty_big)["cost"]
    history = [current_cost]

    for _ in range(max_iter):
        improving = []
        for nb in get_all_neighbors(current, k_max):
            c = objective(nb, positions, weights, penalty_big)["cost"]
            if c < current_cost:
                improving.append((c, nb))

        if not improving:
            break  # local optimum

        chosen_cost, chosen = improving[rng.integers(len(improving))]
        current, current_cost = chosen, chosen_cost
        history.append(current_cost)

    return current, history


# Hill-Climbing varian Random Restart

def hill_climbing_random_restart(n: int, k_max: int, positions: np.ndarray,
                                  weights: dict = None, penalty_big: float = 50.0,
                                  n_restarts: int = 10, max_iter: int = 300,
                                  rng: np.random.Generator = None):
    """Menjalankan steepest-ascent dari n_restarts initial state acak yang independen.

    Satu kali hill-climbing hanya mencapai local optimum dari basin tempatnya
    berangkat, sehingga memulai ulang dari tempat lain menyampel basin yang
    berbeda.

    Mengembalikan (best_state, history, restart_costs), dengan restart_costs
    berisi cost akhir tiap restart sehingga sebaran antar basin terlihat.
    """
    rng = rng or np.random.default_rng()

    best, best_cost = None, np.inf
    history, restart_costs = [], []

    for _ in range(n_restarts):
        A0 = random_initial_state(n, k_max, rng)
        final, run_history = hill_climbing_steepest_ascent(
            A0, k_max, positions, weights, penalty_big, max_iter)
        final_cost = run_history[-1]
        restart_costs.append(final_cost)

        if final_cost < best_cost:
            best, best_cost = final.copy(), final_cost

        # Best-so-far, supaya kurvanya sebanding dengan algoritma lain.
        for c in run_history:
            history.append(min(c, history[-1]) if history else c)

    return best, history, restart_costs


# Simulated Annealing

def simulated_annealing(A0: np.ndarray, k_max: int, positions: np.ndarray,
                         weights: dict = None, penalty_big: float = 50.0,
                         T0: float = 10.0, cooling_rate: float = 0.995,
                         max_iter: int = 3000, rng: np.random.Generator = None):
    rng = rng or np.random.default_rng()
    current = A0.copy()
    current_cost = objective(current, positions, weights, penalty_big)["cost"]
    best, best_cost = current.copy(), current_cost
    history = [current_cost]
    T = T0

    for _ in range(max_iter):
        nb = get_random_neighbor(current, k_max, rng)
        nb_cost = objective(nb, positions, weights, penalty_big)["cost"]
        delta = nb_cost - current_cost

        if delta < 0 or rng.random() < np.exp(-delta / max(T, 1e-9)):
            current, current_cost = nb, nb_cost
            if current_cost < best_cost:
                best, best_cost = current.copy(), current_cost

        T *= cooling_rate
        history.append(current_cost)

    return best, history


# Genetic Algorithm

def ga_crossover(A1: np.ndarray, A2: np.ndarray, rng: np.random.Generator):
    # Uniform crossover pada bit segitiga atas matriks adjacency.
    n = A1.shape[0]
    child1, child2 = np.zeros_like(A1), np.zeros_like(A1)
    mask = rng.random((n, n)) < 0.5
    for i in range(n):
        for j in range(i + 1, n):
            if mask[i, j]:
                child1[i, j] = child1[j, i] = A1[i, j]
                child2[i, j] = child2[j, i] = A2[i, j]
            else:
                child1[i, j] = child1[j, i] = A2[i, j]
                child2[i, j] = child2[j, i] = A1[i, j]
    return child1, child2


def ga_mutate(A: np.ndarray, mutation_rate: float, rng: np.random.Generator) -> np.ndarray:
    n = A.shape[0]
    B = A.copy()
    flips = rng.random((n, n)) < mutation_rate
    for i in range(n):
        for j in range(i + 1, n):
            if flips[i, j]:
                B[i, j] = B[j, i] = 1 - B[i, j]
    return B


def repair_degree(A: np.ndarray, k_max: int, rng: np.random.Generator) -> np.ndarray:
    # Crossover/mutasi bisa melanggar degree cap. Perbaiki dengan menghapus edge
    # acak pada node yang kelebihan sampai semuanya memenuhi k_max.
    n = A.shape[0]
    B = A.copy()
    deg = degrees(B)
    while (deg > k_max).any():
        i = int(np.argmax(deg > k_max))
        neighbors_i = np.nonzero(B[i])[0]
        j = neighbors_i[rng.integers(len(neighbors_i))]
        B[i, j] = B[j, i] = 0
        deg = degrees(B)
    return B


def _tournament_select(population, costs, k, rng):
    idxs = rng.integers(0, len(population), size=k)
    best_idx = idxs[np.argmin([costs[i] for i in idxs])]
    return population[best_idx]


def genetic_algorithm(n: int, k_max: int, positions: np.ndarray,
                       weights: dict = None, penalty_big: float = 50.0,
                       pop_size: int = 40, generations: int = 150,
                       crossover_rate: float = 0.8, mutation_rate: float = 0.02,
                       tournament_k: int = 3, rng: np.random.Generator = None):
    rng = rng or np.random.default_rng()

    population = [random_initial_state(n, k_max, rng) for _ in range(pop_size)]
    costs = [objective(ind, positions, weights, penalty_big)["cost"] for ind in population]

    best_idx = int(np.argmin(costs))
    best, best_cost = population[best_idx].copy(), costs[best_idx]
    history = [best_cost]

    for _ in range(generations):
        new_population = [best.copy()]  # elitism

        while len(new_population) < pop_size:
            p1 = _tournament_select(population, costs, tournament_k, rng)
            p2 = _tournament_select(population, costs, tournament_k, rng)

            if rng.random() < crossover_rate:
                c1, c2 = ga_crossover(p1, p2, rng)
            else:
                c1, c2 = p1.copy(), p2.copy()

            c1 = repair_degree(ga_mutate(c1, mutation_rate, rng), k_max, rng)
            c2 = repair_degree(ga_mutate(c2, mutation_rate, rng), k_max, rng)

            new_population.append(c1)
            if len(new_population) < pop_size:
                new_population.append(c2)

        population = new_population
        costs = [objective(ind, positions, weights, penalty_big)["cost"] for ind in population]

        gen_best_idx = int(np.argmin(costs))
        if costs[gen_best_idx] < best_cost:
            best, best_cost = population[gen_best_idx].copy(), costs[gen_best_idx]

        history.append(best_cost)

    return best, history
