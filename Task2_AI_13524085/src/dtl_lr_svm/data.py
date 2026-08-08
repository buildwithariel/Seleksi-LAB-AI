"""Loading dan preprocessing dataset Loan Approval Classification.
Hanya memakai pandas untuk I/O tabular dan numpy untuk operasi numerik.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

TARGET = "loan_status"
ID_COL = "person_id"

# Batas clipping untuk outlier salah input yang ditemukan saat EDA: ada beberapa
# baris dengan person_age sampai 144 tahun dan person_emp_exp sampai 125 tahun.
AGE_CAP = 100
EMP_EXP_CAP = 60

CATEGORICAL_BINARY = {
    "person_gender": {"male": 1, "female": 0},
    "previous_loan_defaults_on_file": {"Yes": 1, "No": 0},
}
CATEGORICAL_ONEHOT = "person_home_ownership"

# person_income sangat right-skewed (skewness ~37), sehingga setelah z-score
# segelintir income raksasa mendominasi skala dan menggencet sisanya. log1p
# memperbaikinya untuk LR dan SVM (+0.005 masing-masing). CART kebal terhadap
# transformasi monoton, jadi aman diterapkan global dan pipeline-nya tetap satu.
LOG1P_COLS = ["person_income", "loan_amnt"]


def load_raw(data_dir: str = "data"):
    train = pd.read_csv(f"{data_dir}/train.csv")
    test = pd.read_csv(f"{data_dir}/test.csv")
    return train, test


def clean(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["person_age"] = df["person_age"].clip(upper=AGE_CAP)
    df["person_emp_exp"] = df["person_emp_exp"].clip(upper=EMP_EXP_CAP)
    for col in LOG1P_COLS:
        df[col] = np.log1p(df[col])
    return df


def encode(df: pd.DataFrame, onehot_categories: list[str] | None = None):
    # Mengembalikan (encoded_df, onehot_categories) supaya himpunan kategori dan
    # urutan kolom hasil train dapat diterapkan sama persis ke test.
    df = df.copy()
    for col, mapping in CATEGORICAL_BINARY.items():
        df[col] = df[col].map(mapping)

    if onehot_categories is None:
        onehot_categories = sorted(df[CATEGORICAL_ONEHOT].unique().tolist())

    for cat in onehot_categories:
        df[f"{CATEGORICAL_ONEHOT}_{cat}"] = (df[CATEGORICAL_ONEHOT] == cat).astype(int)
    df = df.drop(columns=[CATEGORICAL_ONEHOT])

    return df, onehot_categories


def feature_columns(df: pd.DataFrame) -> list[str]:
    return [c for c in df.columns if c not in (ID_COL, TARGET)]


def to_xy(df: pd.DataFrame, columns: list[str]):
    X = df[columns].to_numpy(dtype=float)
    y = df[TARGET].to_numpy(dtype=float) if TARGET in df.columns else None
    return X, y


def fit_standardizer(X: np.ndarray):
    mean = X.mean(axis=0)
    std = X.std(axis=0)
    std[std == 0] = 1.0
    return mean, std


def standardize(X: np.ndarray, mean: np.ndarray, std: np.ndarray) -> np.ndarray:
    return (X - mean) / std


def k_fold_indices(n: int, k: int, seed: int = 42):
    rng = np.random.default_rng(seed)
    idx = rng.permutation(n)
    folds = np.array_split(idx, k)
    for i in range(k):
        val_idx = folds[i]
        train_idx = np.concatenate([folds[j] for j in range(k) if j != i])
        yield train_idx, val_idx


def class_balanced_sample_weight(y: np.ndarray) -> np.ndarray:
    # weight_c = n_samples / (n_classes * n_c), bobot 'balanced' standar.
    n = len(y)
    classes, counts = np.unique(y, return_counts=True)
    weight_per_class = {c: n / (len(classes) * cnt) for c, cnt in zip(classes, counts)}
    return np.array([weight_per_class[v] for v in y])


def prepare_train_test(data_dir: str = "data"):
    # load -> clean -> encode, mengembalikan (train_df, test_df, feature_cols).
    train_raw, test_raw = load_raw(data_dir)
    train_clean = clean(train_raw)
    test_clean = clean(test_raw)

    train_enc, onehot_cats = encode(train_clean, onehot_categories=None)
    test_enc, _ = encode(test_clean, onehot_categories=onehot_cats)

    cols = feature_columns(train_enc)
    return train_enc, test_enc, cols
