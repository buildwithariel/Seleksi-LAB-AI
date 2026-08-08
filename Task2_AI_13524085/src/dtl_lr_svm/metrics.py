from __future__ import annotations

import numpy as np


def precision_recall_f1(y_true: np.ndarray, y_pred: np.ndarray, positive_class: int):
    tp = float(np.sum((y_pred == positive_class) & (y_true == positive_class)))
    fp = float(np.sum((y_pred == positive_class) & (y_true != positive_class)))
    fn = float(np.sum((y_pred != positive_class) & (y_true == positive_class)))

    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0
    return precision, recall, f1


def macro_f1(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    _, _, f1_0 = precision_recall_f1(y_true, y_pred, 0)
    _, _, f1_1 = precision_recall_f1(y_true, y_pred, 1)
    return (f1_0 + f1_1) / 2.0


def accuracy(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    return float(np.mean(y_true == y_pred))


def best_threshold_macro_f1(y_true: np.ndarray, proba: np.ndarray, n_steps: int = 197):
    # Memindai cutoff di (0, 1) dan mengembalikan yang memaksimalkan macro F1.
    # Pemanggil wajib memakai data terpisah agar skor validasi tidak bocor.
    thresholds = np.linspace(0.01, 0.99, n_steps)
    best_t, best_f1 = 0.5, -1.0
    for t in thresholds:
        f1 = macro_f1(y_true, (proba >= t).astype(int))
        if f1 > best_f1:
            best_f1, best_t = f1, float(t)
    return best_t, best_f1

