"""Representasi state, successor/neighbor function, dan objective function untuk
persoalan local search Data Center Network Topology Design.

State direpresentasikan sebagai matriks adjacency biner simetris N x N (numpy
array) dengan diagonal bernilai 0.
"""
from __future__ import annotations

import numpy as np
from collections import deque


# Penyiapan instance permasalahan

def generate_positions(n: int, seed: int | None = None, grid: float = 100.0) -> np.ndarray:
    # Posisi node tetap per instance dan bukan bagian dari ruang pencarian.
    rng = np.random.default_rng(seed)
    return rng.uniform(0.0, grid, size=(n, 2))


def degrees(A: np.ndarray) -> np.ndarray:
    return A.sum(axis=1).astype(int)


def get_degree(A: np.ndarray, i: int) -> int:
    return int(A[i].sum())


# Initial state

def random_initial_state(n: int, k_max: int, rng: np.random.Generator,
                          extra_edge_attempts: int | None = None) -> np.ndarray:
    """Membangun topologi awal acak yang connected dan memenuhi degree cap.

    Langkah 1: random spanning tree, menjamin graf terhubung.
    Langkah 2: beberapa edge tambahan acak sebagai redundansi awal.
    """
    A = np.zeros((n, n), dtype=np.int8)
    deg = np.zeros(n, dtype=int)

    order = rng.permutation(n)
    in_tree = [order[0]]
    remaining = list(order[1:])

    while remaining:
        candidates_in_tree = [u for u in in_tree if deg[u] < k_max]
        if not candidates_in_tree:
            raise ValueError("k_max terlalu kecil untuk membentuk spanning tree pada N node ini")
        u = candidates_in_tree[rng.integers(len(candidates_in_tree))]
        v = remaining.pop(rng.integers(len(remaining)))
        A[u, v] = A[v, u] = 1
        deg[u] += 1
        deg[v] += 1
        in_tree.append(v)

    extra_edge_attempts = extra_edge_attempts if extra_edge_attempts is not None else n
    for _ in range(extra_edge_attempts):
        i, j = rng.integers(0, n, size=2)
        if i == j or A[i, j] == 1:
            continue
        if deg[i] < k_max and deg[j] < k_max:
            A[i, j] = A[j, i] = 1
            deg[i] += 1
            deg[j] += 1

    return A


# Successor / neighbor function

def get_all_neighbors(A: np.ndarray, k_max: int) -> list[np.ndarray]:
    # Seluruh neighbor yang dicapai dengan tepat satu move ADD / REMOVE / REWIRE.
    n = A.shape[0]
    deg = degrees(A)
    neighbors = []

    # ADD_EDGE(i, j)
    for i in range(n):
        for j in range(i + 1, n):
            if A[i, j] == 0 and deg[i] < k_max and deg[j] < k_max:
                B = A.copy()
                B[i, j] = B[j, i] = 1
                neighbors.append(B)

    # REMOVE_EDGE(i, j)
    for i in range(n):
        for j in range(i + 1, n):
            if A[i, j] == 1:
                B = A.copy()
                B[i, j] = B[j, i] = 0
                neighbors.append(B)

    # REWIRE(i, j -> k): pindahkan satu ujung edge {i,j} ke node lain k
    edges = [(i, j) for i in range(n) for j in range(i + 1, n) if A[i, j] == 1]
    for (i, j) in edges:
        for k in range(n):
            if k == i or k == j or A[i, k] == 1:
                continue
            if deg[k] < k_max:
                B = A.copy()
                B[i, j] = B[j, i] = 0
                B[i, k] = B[k, i] = 1
                neighbors.append(B)
            if deg[k] < k_max and A[j, k] == 0:
                B = A.copy()
                B[i, j] = B[j, i] = 0
                B[j, k] = B[k, j] = 1
                neighbors.append(B)

    return neighbors


def get_random_neighbor(A: np.ndarray, k_max: int, rng: np.random.Generator,
                         max_tries: int = 200) -> np.ndarray:
    n = A.shape[0]
    for _ in range(max_tries):
        move = rng.choice(["add", "remove", "rewire"])
        deg = degrees(A)

        if move == "add":
            i, j = rng.integers(0, n, size=2)
            if i == j or A[i, j] == 1:
                continue
            if deg[i] < k_max and deg[j] < k_max:
                B = A.copy()
                B[i, j] = B[j, i] = 1
                return B

        elif move == "remove":
            edges = np.argwhere(np.triu(A, k=1) == 1)
            if len(edges) == 0:
                continue
            i, j = edges[rng.integers(len(edges))]
            B = A.copy()
            B[i, j] = B[j, i] = 0
            return B

        else:  # rewire
            edges = np.argwhere(np.triu(A, k=1) == 1)
            if len(edges) == 0:
                continue
            i, j = edges[rng.integers(len(edges))]
            if rng.random() < 0.5:
                i, j = j, i
            k = rng.integers(0, n)
            if k == i or k == j or A[i, k] == 1 or deg[k] >= k_max:
                continue
            B = A.copy()
            B[i, j] = B[j, i] = 0
            B[i, k] = B[k, i] = 1
            return B

    return A.copy()  # cadangan: tidak ada move valid dalam max_tries percobaan


# Metrik graf yang dipakai objective function

def count_components(A: np.ndarray) -> int:
    n = A.shape[0]
    visited = [False] * n
    comps = 0
    for s in range(n):
        if visited[s]:
            continue
        comps += 1
        q = deque([s])
        visited[s] = True
        while q:
            u = q.popleft()
            for v in np.nonzero(A[u])[0]:
                if not visited[v]:
                    visited[v] = True
                    q.append(v)
    return comps


def avg_shortest_path(A: np.ndarray, sentinel: float | None = None) -> float:
    # Rata-rata jarak hop BFS antar seluruh pasang node. Pasangan yang terputus
    # memakai jarak sentinel agar hasilnya tetap finite.
    n = A.shape[0]
    sentinel = sentinel if sentinel is not None else 2.0 * n
    total = 0.0
    pairs = n * (n - 1) / 2

    for s in range(n):
        dist = [-1] * n
        dist[s] = 0
        q = deque([s])
        while q:
            u = q.popleft()
            for v in np.nonzero(A[u])[0]:
                if dist[v] == -1:
                    dist[v] = dist[u] + 1
                    q.append(v)
        for t in range(s + 1, n):
            total += dist[t] if dist[t] != -1 else sentinel

    return total / pairs


def count_bridges(A: np.ndarray) -> int:
    # Pencarian bridge ala Tarjan (DFS iteratif): jumlah edge single-point-of-failure.
    n = A.shape[0]
    adj = [np.nonzero(A[u])[0].tolist() for u in range(n)]
    disc = [-1] * n
    low = [-1] * n
    timer = [0]
    bridges = 0

    for start in range(n):
        if disc[start] != -1:
            continue
        stack = [(start, -1, iter(adj[start]))]
        disc[start] = low[start] = timer[0]
        timer[0] += 1

        while stack:
            u, parent, it = stack[-1]
            advanced = False
            for v in it:
                if v == parent:
                    continue
                if disc[v] == -1:
                    disc[v] = low[v] = timer[0]
                    timer[0] += 1
                    stack.append((v, u, iter(adj[v])))
                    advanced = True
                    break
                else:
                    low[u] = min(low[u], disc[v])
            if not advanced:
                stack.pop()
                if stack:
                    p_u, p_parent, p_it = stack[-1]
                    low[p_u] = min(low[p_u], low[u])
                    if low[u] > disc[p_u]:
                        bridges += 1

    return bridges


def cable_cost(A: np.ndarray, positions: np.ndarray) -> float:
    # Total panjang kabel euclidean, dinormalisasi terhadap biaya complete graph.
    n = A.shape[0]
    diff = positions[:, None, :] - positions[None, :, :]
    dist = np.sqrt((diff ** 2).sum(axis=-1))
    total_cost = (dist * np.triu(A, k=1)).sum()
    total_complete = np.triu(dist, k=1).sum()
    return float(total_cost / total_complete) if total_complete > 0 else 0.0


# Objective function

DEFAULT_WEIGHTS = dict(w_L=1.0, w_C=1.0, w_B=0.5, w_D=1.0)
DEFAULT_PENALTY_BIG = 50.0


def objective(A: np.ndarray, positions: np.ndarray, weights: dict = None,
              penalty_big: float = DEFAULT_PENALTY_BIG) -> dict:
    # Cost gabungan yang DIMINIMALKAN: latensi + biaya kabel + bridge + penalti disconnect.
    w = weights or DEFAULT_WEIGHTS
    n = A.shape[0]

    L = avg_shortest_path(A)
    C = cable_cost(A, positions)
    B = count_bridges(A)
    comps = count_components(A)
    D = comps - 1

    cost = w["w_L"] * L + w["w_C"] * C + w["w_B"] * B + w["w_D"] * D * penalty_big

    return {
        "cost": float(cost),
        "latency": float(L),
        "cable_cost": float(C),
        "bridges": int(B),
        "components": int(comps),
    }


def describe_state(A: np.ndarray, positions: np.ndarray, weights: dict = None,
                    penalty_big: float = DEFAULT_PENALTY_BIG) -> str:
    n = A.shape[0]
    edges = [(i, j) for i in range(n) for j in range(i + 1, n) if A[i, j] == 1]
    deg = degrees(A).tolist()
    o = objective(A, positions, weights, penalty_big)
    lines = [
        f"Jumlah edge : {len(edges)}",
        f"Edge list   : {edges}",
        f"Degree/node : {deg}",
        f"cost={o['cost']:.4f} | latency={o['latency']:.4f} | cable_cost={o['cable_cost']:.4f} "
        f"| bridges={o['bridges']} | components={o['components']}",
    ]
    return "\n".join(lines)
