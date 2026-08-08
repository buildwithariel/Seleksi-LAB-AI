"""Cross-validation DTL (CART), Logistic Regression, dan SVM from scratch
terhadap padanannya di scikit-learn, lalu menghasilkan berkas submission.

    python train.py
"""
import os
import time

import numpy as np
import pandas as pd

from data import prepare_train_test, to_xy, fit_standardizer, standardize, \
    k_fold_indices, class_balanced_sample_weight, TARGET, ID_COL
from metrics import macro_f1, accuracy
from algoritma.decision_tree import DecisionTreeCARTScratch
from algoritma.logistic_regression import LogisticRegressionScratch
from algoritma.svm import LinearSVMScratch

from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.svm import LinearSVC

SEED = 42
N_FOLDS = 5

# Keluaran berupa berkas csv disimpan di result/ sebelah skrip ini, apa pun
# direktori kerja saat dijalankan.
RESULT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "result")

# Tumbuhkan besar lalu pangkas. Grid depth/min_samples mentok di 0.8703 sementara
# pruning mencapai 0.8747. Nilai alpha diambil dari sweep di improve_experiments.py.
TREE_PARAMS = dict(max_depth=16, min_samples_split=10, min_samples_leaf=5,
                   ccp_alpha=3e-4)


def cross_validate(name, fit_predict_fn, X, y, k=N_FOLDS):
    scores, times = [], []
    for fold, (tr_idx, va_idx) in enumerate(k_fold_indices(len(y), k, seed=SEED)):
        t0 = time.time()
        pred = fit_predict_fn(X[tr_idx], y[tr_idx], X[va_idx])
        dt = time.time() - t0
        f1 = macro_f1(y[va_idx], pred)
        acc = accuracy(y[va_idx], pred)
        scores.append(f1)
        times.append(dt)
        print(f"  [{name}] fold {fold+1}/{k}: macro_f1={f1:.4f} acc={acc:.4f} ({dt:.1f}s)")
    print(f"  [{name}] CV macro_f1 = {np.mean(scores):.4f} +/- {np.std(scores):.4f}")
    return scores


def main():
    print("Memuat dan memproses data...")
    train_df, test_df, cols = prepare_train_test("../../data")
    X_all, y_all = to_xy(train_df, cols)
    X_test, _ = to_xy(test_df, cols)
    print(f"Ukuran train: {X_all.shape}, ukuran test: {X_test.shape}")
    print(f"Fitur ({len(cols)}): {cols}")

    # 1) Decision Tree Learning (CART), tidak perlu penskalaan fitur
    print("\n=== Decision Tree Learning (CART, from scratch) ===")

    # sample_weight dibiarkan None: class-balanced weighting menurunkan macro F1
    # pada ketiga model di sini (lihat write-up bagian "Percobaan yang Gagal").
    def dtl_scratch_fit_predict(Xtr, ytr, Xva):
        model = DecisionTreeCARTScratch(**TREE_PARAMS)
        model.fit(Xtr, ytr, sample_weight=None)
        return model.predict(Xva)

    dtl_scratch_scores = cross_validate("DTL-scratch", dtl_scratch_fit_predict, X_all, y_all)

    def dtl_sklearn_fit_predict(Xtr, ytr, Xva):
        model = DecisionTreeClassifier(max_depth=TREE_PARAMS["max_depth"],
                                        min_samples_split=TREE_PARAMS["min_samples_split"],
                                        min_samples_leaf=TREE_PARAMS["min_samples_leaf"],
                                        ccp_alpha=TREE_PARAMS["ccp_alpha"],
                                        random_state=SEED)
        model.fit(Xtr, ytr, sample_weight=None)
        return model.predict(Xva)

    dtl_sklearn_scores = cross_validate("DTL-sklearn", dtl_sklearn_fit_predict, X_all, y_all)

    # 2) Logistic Regression, butuh fitur yang sudah distandardisasi
    print("\n=== Logistic Regression (from scratch) ===")

    def lr_scratch_fit_predict(Xtr, ytr, Xva):
        mean, std = fit_standardizer(Xtr)
        Xtr_s, Xva_s = standardize(Xtr, mean, std), standardize(Xva, mean, std)
        model = LogisticRegressionScratch(lr=0.5, n_epochs=800, l2=1e-3)
        model.fit(Xtr_s, ytr, sample_weight=None)
        return model.predict(Xva_s)

    lr_scratch_scores = cross_validate("LR-scratch", lr_scratch_fit_predict, X_all, y_all)

    def lr_sklearn_fit_predict(Xtr, ytr, Xva):
        mean, std = fit_standardizer(Xtr)
        Xtr_s, Xva_s = standardize(Xtr, mean, std), standardize(Xva, mean, std)
        model = LogisticRegression(max_iter=1000, C=1.0 / (2 * 1e-3))
        model.fit(Xtr_s, ytr)
        return model.predict(Xva_s)

    lr_sklearn_scores = cross_validate("LR-sklearn", lr_sklearn_fit_predict, X_all, y_all)

    # 3) SVM, butuh fitur yang sudah distandardisasi
    print("\n=== SVM (from scratch, linear, Pegasos) ===")

    def svm_scratch_fit_predict(Xtr, ytr, Xva):
        mean, std = fit_standardizer(Xtr)
        Xtr_s, Xva_s = standardize(Xtr, mean, std), standardize(Xva, mean, std)
        model = LinearSVMScratch(lam=1e-3, n_epochs=15, batch_size=256, seed=SEED)
        model.fit(Xtr_s, ytr, sample_weight=None)
        return model.predict(Xva_s)

    svm_scratch_scores = cross_validate("SVM-scratch", svm_scratch_fit_predict, X_all, y_all)

    def svm_sklearn_fit_predict(Xtr, ytr, Xva):
        mean, std = fit_standardizer(Xtr)
        Xtr_s, Xva_s = standardize(Xtr, mean, std), standardize(Xva, mean, std)
        model = LinearSVC(max_iter=5000, C=1.0)
        model.fit(Xtr_s, ytr)
        return model.predict(Xva_s)

    svm_sklearn_scores = cross_validate("SVM-sklearn", svm_sklearn_fit_predict, X_all, y_all)

    # Tabel ringkasan
    print("\n" + "=" * 60)
    print("RINGKASAN CROSS-VALIDATION (5-fold macro F1)")
    print("=" * 60)
    summary = pd.DataFrame({
        "model": ["DTL-scratch", "DTL-sklearn", "LR-scratch", "LR-sklearn",
                  "SVM-scratch", "SVM-sklearn"],
        "mean_macro_f1": [np.mean(s) for s in (dtl_scratch_scores, dtl_sklearn_scores,
                                                 lr_scratch_scores, lr_sklearn_scores,
                                                 svm_scratch_scores, svm_sklearn_scores)],
        "std_macro_f1": [np.std(s) for s in (dtl_scratch_scores, dtl_sklearn_scores,
                                               lr_scratch_scores, lr_sklearn_scores,
                                               svm_scratch_scores, svm_sklearn_scores)],
    })
    print(summary.to_string(index=False))
    os.makedirs(RESULT_DIR, exist_ok=True)
    summary.to_csv(os.path.join(RESULT_DIR, "cv_summary.csv"), index=False)

    # Latih ulang model from-scratch terbaik (berdasarkan rata-rata CV macro F1)
    # pada seluruh data latih, lalu buat berkas submission Kaggle.
    best_name = summary.loc[summary["model"].str.endswith("scratch"), :] \
        .sort_values("mean_macro_f1", ascending=False).iloc[0]["model"]
    print(f"\nModel from-scratch terbaik berdasarkan CV: {best_name}")

    mean, std = fit_standardizer(X_all)
    X_all_s = standardize(X_all, mean, std)
    X_test_s = standardize(X_test, mean, std)

    if best_name == "DTL-scratch":
        final_model = DecisionTreeCARTScratch(**TREE_PARAMS)
        final_model.fit(X_all, y_all, sample_weight=None)
        print(f"Tree final: {final_model.n_leaves()} leaf setelah pruning "
              f"(depth {final_model.depth()})")
        test_pred = final_model.predict(X_test)
    elif best_name == "LR-scratch":
        final_model = LogisticRegressionScratch(lr=0.5, n_epochs=800, l2=1e-3)
        final_model.fit(X_all_s, y_all, sample_weight=None)
        test_pred = final_model.predict(X_test_s)
    else:
        final_model = LinearSVMScratch(lam=1e-3, n_epochs=15, batch_size=256, seed=SEED)
        final_model.fit(X_all_s, y_all, sample_weight=None)
        test_pred = final_model.predict(X_test_s)

    submission = pd.DataFrame({
        ID_COL: test_df[ID_COL].values,
        TARGET: test_pred.astype(int),
    })
    submission.to_csv(os.path.join(RESULT_DIR, "submission.csv"), index=False)
    print(f"result/submission.csv ditulis ({len(submission)} baris). "
          f"Distribusi prediksi: {submission[TARGET].value_counts().to_dict()}")


if __name__ == "__main__":
    main()
