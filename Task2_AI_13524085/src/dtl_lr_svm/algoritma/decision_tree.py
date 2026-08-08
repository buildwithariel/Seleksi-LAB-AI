"""CART untuk klasifikasi biner: Gini impurity, split biner, dengan opsi
cost-complexity pruning."""
from __future__ import annotations

import numpy as np


def _gini(w0: np.ndarray, w1: np.ndarray) -> np.ndarray:
    total = w0 + w1
    p0 = np.divide(w0, total, out=np.zeros_like(w0), where=total > 0)
    p1 = np.divide(w1, total, out=np.zeros_like(w1), where=total > 0)
    return 1.0 - p0 ** 2 - p1 ** 2


def _best_split_for_feature(x: np.ndarray, y: np.ndarray, w: np.ndarray,
                            min_samples_leaf: int = 1):
    order = np.argsort(x, kind="mergesort")
    xs, ys, ws = x[order], y[order], w[order]

    total_w = ws.sum()
    total_w1 = (ws * ys).sum()
    total_w0 = total_w - total_w1

    cum_w = np.cumsum(ws)
    cum_w1 = np.cumsum(ws * ys)

    n = len(xs)
    if n < 2:
        return None

    idx = np.arange(1, n)  # kandidat split setelah posisi idx-1
    left_w = cum_w[idx - 1]
    left_w1 = cum_w1[idx - 1]
    left_w0 = left_w - left_w1
    right_w = total_w - left_w
    right_w1 = total_w1 - left_w1
    right_w0 = total_w0 - left_w0

    # Split pada posisi idx menaruh idx baris di kiri dan n-idx baris di kanan.
    # min_samples_leaf dicek di sini, bukan setelahnya: kalau threshold terbaik
    # ternyata split ilegal yang terlalu tipis, node langsung jadi leaf padahal
    # ada split legal yang sedikit lebih buruk.
    valid = ((xs[idx - 1] != xs[idx]) & (left_w > 0) & (right_w > 0)
             & (idx >= min_samples_leaf) & ((n - idx) >= min_samples_leaf))
    if not valid.any():
        return None

    gini_left = _gini(left_w0, left_w1)
    gini_right = _gini(right_w0, right_w1)
    weighted = (left_w / total_w) * gini_left + (right_w / total_w) * gini_right
    weighted = np.where(valid, weighted, np.inf)

    best_pos = int(np.argmin(weighted))
    if not np.isfinite(weighted[best_pos]):
        return None

    threshold = (xs[idx[best_pos] - 1] + xs[idx[best_pos]]) / 2.0
    return threshold, float(weighted[best_pos])


class _Node:
    __slots__ = ("is_leaf", "proba", "feature", "threshold", "left", "right",
                 "n_weighted", "impurity")

    def __init__(self):
        self.is_leaf = True
        self.proba = 0.5
        self.feature = None
        self.threshold = None
        self.left = None
        self.right = None
        self.n_weighted = 0.0   # total bobot sampel yang sampai ke node ini
        self.impurity = 0.0     # Gini impurity node ini, dipakai saat pruning


class DecisionTreeCARTScratch:
    """Ukuran tree dibatasi lewat dua cara.

    Pre-pruning (max_depth, min_samples_split, min_samples_leaf) menghentikan
    pertumbuhan lebih awal. Post-pruning (ccp_alpha) menumbuhkan tree besar dulu,
    lalu memangkas subtree yang tidak sepadan dengan tambahan leaf-nya.
    """

    def __init__(self, max_depth: int = 8, min_samples_split: int = 40,
                 min_samples_leaf: int = 20, min_impurity_decrease: float = 1e-5,
                 ccp_alpha: float = 0.0):
        self.max_depth = max_depth
        self.min_samples_split = min_samples_split
        self.min_samples_leaf = min_samples_leaf
        self.min_impurity_decrease = min_impurity_decrease
        self.ccp_alpha = ccp_alpha
        self.root: _Node | None = None
        self.n_features_ = None

    def fit(self, X: np.ndarray, y: np.ndarray, sample_weight: np.ndarray | None = None):
        y = y.astype(int)
        w = sample_weight if sample_weight is not None else np.ones(len(y))
        self.n_features_ = X.shape[1]
        self.root = self._build(X, y, w, depth=0)
        if self.ccp_alpha > 0:
            self._prune_ccp(self.ccp_alpha)
        return self

    def _build(self, X, y, w, depth) -> _Node:
        node = _Node()
        w1 = (w * y).sum()
        w0 = w.sum() - w1
        node.proba = float(w1 / (w0 + w1)) if (w0 + w1) > 0 else 0.5

        parent_gini = _gini(np.array([w0]), np.array([w1]))[0]
        node.n_weighted = float(w0 + w1)
        node.impurity = float(parent_gini)

        if (depth >= self.max_depth or len(y) < self.min_samples_split
                or parent_gini < 1e-9 or len(np.unique(y)) == 1):
            return node

        best_feature, best_threshold, best_gini = None, None, np.inf
        for f in range(X.shape[1]):
            result = _best_split_for_feature(X[:, f], y, w, self.min_samples_leaf)
            if result is None:
                continue
            threshold, weighted_gini = result
            if weighted_gini < best_gini:
                best_gini, best_feature, best_threshold = weighted_gini, f, threshold

        if best_feature is None or (parent_gini - best_gini) < self.min_impurity_decrease:
            return node

        mask = X[:, best_feature] <= best_threshold
        if mask.sum() < self.min_samples_leaf or (~mask).sum() < self.min_samples_leaf:
            return node

        node.is_leaf = False
        node.feature = best_feature
        node.threshold = best_threshold
        node.left = self._build(X[mask], y[mask], w[mask], depth + 1)
        node.right = self._build(X[~mask], y[~mask], w[~mask], depth + 1)
        return node

    def _prune_ccp(self, alpha: float):
        """Minimal cost-complexity pruning (Breiman et al., 1984).

        Tree dinilai dengan R_alpha(T) = R(T) + alpha * n_leaves, dengan R(T)
        adalah Gini cost berbobot pada seluruh leaf. Tiap leaf berharga alpha,
        jadi sebuah subtree hanya dipertahankan bila akurasi yang dibelinya
        menutup harga itu.

        Subtree optimal didapat lewat satu lintasan bottom-up: di tiap node,
        bandingkan biaya menjadikannya leaf (R(t) + alpha) dengan biaya
        mempertahankan split (best_cost(left) + best_cost(right)), lalu ambil
        yang lebih murah. Nilai seri dijadikan leaf, sehingga hasilnya adalah
        tree terkecil di antara yang sama baiknya.

        Catatan: memangkas semua node dengan
        g(t) = (R(t) - R(subtree)) / (leaves - 1) <= alpha dalam satu sapuan
        terlihat setara padahal tidak. Memangkas satu node mengubah g seluruh
        leluhurnya, jadi satu sapuan akan over-prune. Sempat dicoba dan tree-nya
        runtuh jadi 2 leaf dengan macro F1 turun ke 0.44.
        """
        total_w = self.root.n_weighted

        def best_cost(node) -> float:
            # Biaya subtree optimal di node ini, sekaligus memangkas di tempat.
            cost_as_leaf = node.n_weighted / total_w * node.impurity + alpha
            if node.is_leaf:
                return cost_as_leaf

            cost_of_keeping = best_cost(node.left) + best_cost(node.right)
            if cost_as_leaf <= cost_of_keeping:
                node.is_leaf = True
                node.left = None
                node.right = None
                node.feature = None
                node.threshold = None
                return cost_as_leaf
            return cost_of_keeping

        best_cost(self.root)

    def n_leaves(self) -> int:
        def rec(node):
            return 1 if node.is_leaf else rec(node.left) + rec(node.right)
        return rec(self.root)

    def _predict_row_proba(self, x: np.ndarray) -> float:
        node = self.root
        while not node.is_leaf:
            node = node.left if x[node.feature] <= node.threshold else node.right
        return node.proba

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        return np.array([self._predict_row_proba(x) for x in X])

    def predict(self, X: np.ndarray, threshold: float = 0.5) -> np.ndarray:
        return (self.predict_proba(X) >= threshold).astype(int)

    # Helper introspeksi, dipakai untuk gambar tree pada bagian bonus.
    def to_dict(self, feature_names: list[str] | None = None) -> dict:
        def rec(node: _Node):
            common = {"proba": round(node.proba, 4),
                      "n": int(round(node.n_weighted)),
                      "gini": round(node.impurity, 4)}
            if node.is_leaf:
                return {"leaf": True, **common}
            fname = feature_names[node.feature] if feature_names else f"x{node.feature}"
            return {
                "leaf": False,
                **common,
                "feature": fname,
                "threshold": round(float(node.threshold), 4),
                "left": rec(node.left),
                "right": rec(node.right),
            }
        return rec(self.root)

    def depth(self) -> int:
        def rec(node: _Node):
            if node.is_leaf:
                return 0
            return 1 + max(rec(node.left), rec(node.right))
        return rec(self.root)
