"""Logistic Regression: binary cross-entropy dengan regularisasi L2, dioptimasi
memakai full-batch gradient descent."""
from __future__ import annotations

import numpy as np


def _sigmoid(z: np.ndarray) -> np.ndarray:
    return np.where(z >= 0, 1.0 / (1.0 + np.exp(-z)), np.exp(z) / (1.0 + np.exp(z)))


class LogisticRegressionScratch:
    def __init__(self, lr: float = 0.1, n_epochs: int = 1000, l2: float = 1e-3,
                 fit_intercept: bool = True, record_history: bool = False):
        self.lr = lr
        self.n_epochs = n_epochs
        self.l2 = l2
        self.fit_intercept = fit_intercept
        self.record_history = record_history
        self.weights = None
        self.bias = 0.0
        self.loss_history = []
        self.weight_history = []  # untuk gambar kontur loss dan lintasan parameter

    def _loss(self, X, y, w):
        z = X @ self.weights + self.bias
        p = _sigmoid(z)
        eps = 1e-12
        bce = -(w * (y * np.log(p + eps) + (1 - y) * np.log(1 - p + eps))).sum() / w.sum()
        reg = self.l2 * np.sum(self.weights ** 2)
        return bce + reg

    def fit(self, X: np.ndarray, y: np.ndarray, sample_weight: np.ndarray | None = None):
        n, d = X.shape
        w = sample_weight if sample_weight is not None else np.ones(n)
        w = w / w.sum() * n  # normalisasi supaya learning rate efektifnya sebanding

        self.weights = np.zeros(d)
        self.bias = 0.0

        for epoch in range(self.n_epochs):
            z = X @ self.weights + self.bias
            p = _sigmoid(z)
            error = (p - y) * w

            grad_w = (X.T @ error) / n + 2 * self.l2 * self.weights
            grad_b = error.sum() / n if self.fit_intercept else 0.0

            self.weights -= self.lr * grad_w
            self.bias -= self.lr * grad_b

            if self.record_history:
                self.loss_history.append(self._loss(X, y, w))
                self.weight_history.append(self.weights.copy())

        return self

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        return _sigmoid(X @ self.weights + self.bias)

    def predict(self, X: np.ndarray, threshold: float = 0.5) -> np.ndarray:
        return (self.predict_proba(X) >= threshold).astype(int)