"""SVM linear yang dilatih dengan algoritma Pegasos (Shalev-Shwartz et al., 2007).

Meminimalkan (lambda/2)||w||^2 + (1/n) sum_i max(0, 1 - y_i (w.x_i + b)) memakai
mini-batch stochastic sub-gradient descent. Pegasos dipilih karena tidak butuh
solver quadratic programming untuk bentuk dual-nya, sehingga tetap praktis pada
data ~29 ribu baris.
"""
from __future__ import annotations

import numpy as np


class LinearSVMScratch:
    def __init__(self, lam: float = 1e-3, n_epochs: int = 20, batch_size: int = 256,
                 seed: int = 42):
        self.lam = lam
        self.n_epochs = n_epochs
        self.batch_size = batch_size
        self.seed = seed
        self.weights = None
        self.bias = 0.0
        self.loss_history = []

    def _hinge_loss(self, X, y_pm1, w):
        margins = y_pm1 * (X @ self.weights + self.bias)
        hinge = np.maximum(0.0, 1.0 - margins)
        return 0.5 * self.lam * np.sum(self.weights ** 2) + float(np.sum(w * hinge) / w.sum())

    def fit(self, X: np.ndarray, y: np.ndarray, sample_weight: np.ndarray | None = None):
        n, d = X.shape
        y_pm1 = np.where(y > 0, 1.0, -1.0)
        w = sample_weight if sample_weight is not None else np.ones(n)

        rng = np.random.default_rng(self.seed)
        self.weights = np.zeros(d)
        self.bias = 0.0

        t = 0
        for epoch in range(self.n_epochs):
            perm = rng.permutation(n)
            for start in range(0, n, self.batch_size):
                batch = perm[start:start + self.batch_size]
                t += 1
                eta = 1.0 / (self.lam * t)

                Xb, yb, wb = X[batch], y_pm1[batch], w[batch]
                margins = yb * (Xb @ self.weights + self.bias)
                violate = margins < 1.0

                grad_w = self.lam * self.weights - (
                    (wb[violate, None] * yb[violate, None] * Xb[violate]).sum(axis=0) / len(batch)
                )
                grad_b = -float((wb[violate] * yb[violate]).sum() / len(batch))

                self.weights -= eta * grad_w
                self.bias -= eta * grad_b

            self.loss_history.append(self._hinge_loss(X, y_pm1, w))

        return self

    def decision_function(self, X: np.ndarray) -> np.ndarray:
        return X @ self.weights + self.bias

    def predict(self, X: np.ndarray) -> np.ndarray:
        return (self.decision_function(X) >= 0).astype(int)

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        # Decision function yang dipetakan lewat fungsi logistik. Bukan probabilitas
        # terkalibrasi, hanya dipakai untuk perankingan dan eksperimen threshold.
        z = self.decision_function(X)
        return 1.0 / (1.0 + np.exp(-z))
