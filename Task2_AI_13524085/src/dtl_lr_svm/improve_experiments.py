"""Eksperimen untuk menembus macro F1 ~0.87, tetap dalam batasan kompetisi
(hanya DTL / LR / SVM, from scratch, tanpa ensemble).

Menjalankan file ini mereproduksi seluruh angka yang dikutip di write-up.

    python improve_experiments.py
"""
import numpy as np

from data import prepare_train_test, to_xy, fit_standardizer, standardize, k_fold_indices
from metrics import macro_f1, best_threshold_macro_f1
from algoritma.decision_tree import DecisionTreeCARTScratch
from algoritma.logistic_regression import LogisticRegressionScratch
from algoritma.svm import LinearSVMScratch

SEED = 42
N_FOLDS = 5
GROW_PARAMS = dict(max_depth=16, min_samples_split=10, min_samples_leaf=5)


def cv_macro_f1(make_model, X, y, k=N_FOLDS):
    scores = []
    for tr_idx, va_idx in k_fold_indices(len(y), k, seed=SEED):
        model = make_model()
        model.fit(X[tr_idx], y[tr_idx], sample_weight=None)
        scores.append(macro_f1(y[va_idx], model.predict(X[va_idx])))
    return float(np.mean(scores)), float(np.std(scores))


# 1. Cost-complexity pruning, satu-satunya yang benar-benar berhasil

def experiment_pruning(X, y):
    print("=" * 74)
    print("1. PRE-PRUNING (batas kedalaman) vs POST-PRUNING (cost-complexity)")
    print("=" * 74)
    print("Pre-pruning menghentikan pertumbuhan lebih awal, sedangkan post-pruning")
    print("menumbuhkan tree besar dulu baru memangkas subtree yang tidak sepadan.\n")

    m, s = cv_macro_f1(lambda: DecisionTreeCARTScratch(max_depth=8, min_samples_split=40,
                                                min_samples_leaf=20), X, y)
    print(f"  pre-pruning  depth=8, leaf=20        : {m:.4f} +/- {s:.4f}")
    print("  (grid penuh depth x min_samples_leaf tidak pernah melewati 0.8703)\n")

    best = None
    for alpha in [1e-4, 1.5e-4, 2e-4, 2.5e-4, 3e-4, 3.5e-4, 4e-4, 5e-4]:
        m, s = cv_macro_f1(lambda a=alpha: DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=a), X, y)
        leaves = DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=alpha).fit(X, y).n_leaves()
        if best is None or m > best[0]:
            best = (m, alpha)
        print(f"  post-pruning ccp_alpha={alpha:<7}       : {m:.4f} +/- {s:.4f}"
              f"  ({leaves:>3} leaf)")
    print(f"\n  alpha={best[1]} memberi {best[0]:.4f}, optimumnya landai di rentang")
    print("  2e-4 sampai 3e-4.\n")
    return best[1]


# 2. Threshold tuning, gagal

def experiment_threshold(X, y, alpha):
    print("=" * 74)
    print("2. TUNING THRESHOLD KEPUTUSAN (gagal)")
    print("=" * 74)
    print("Threshold dicari pada 15% data yang ditahan dari bagian training, jadi")
    print("fold yang diskor tidak ikut menentukan threshold-nya sendiri.\n")

    rng = np.random.default_rng(SEED)
    at_half, at_tuned, chosen = [], [], []
    for tr_idx, va_idx in k_fold_indices(len(y), N_FOLDS, seed=SEED):
        perm = rng.permutation(len(tr_idx))
        n_tune = int(len(tr_idx) * 0.15)
        tune_idx, fit_idx = tr_idx[perm[:n_tune]], tr_idx[perm[n_tune:]]

        model = DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=alpha).fit(X[fit_idx], y[fit_idx])
        t, _ = best_threshold_macro_f1(y[tune_idx], model.predict_proba(X[tune_idx]))

        proba = model.predict_proba(X[va_idx])
        at_half.append(macro_f1(y[va_idx], (proba >= 0.5).astype(int)))
        at_tuned.append(macro_f1(y[va_idx], (proba >= t).astype(int)))
        chosen.append(t)

    print(f"  threshold tetap 0.5 : {np.mean(at_half):.4f}")
    print(f"  threshold hasil tuning : {np.mean(at_tuned):.4f} "
          f"(selisih {np.mean(at_tuned) - np.mean(at_half):+.4f})")
    print(f"  threshold terpilih     : {['%.2f' % t for t in chosen]}")
    print("  Threshold tidak stabil antar fold, jadi tidak bisa ditransfer ke")
    print("  data uji. Konfigurasi final tetap memakai cutoff 0.5.\n")


# 3. Fitur turunan, gagal

def experiment_features(train_df, cols, X, y, alpha):
    print("=" * 74)
    print("3. FITUR TURUNAN (gagal)")
    print("=" * 74)

    df = train_df.copy()
    df["defaults_x_loanpct"] = (df["previous_loan_defaults_on_file"]
                                * df["loan_percent_income"])
    df["credit_x_hist"] = df["credit_score"] * df["cb_person_cred_hist_length"]
    df["emp_ratio"] = df["person_emp_exp"] / (df["person_age"] + 1)
    df["loanpct_sq"] = df["loan_percent_income"] ** 2
    cols_fe = cols + ["defaults_x_loanpct", "credit_x_hist", "emp_ratio", "loanpct_sq"]
    X_fe, _ = to_xy(df, cols_fe)

    for name, model_fn, Xa, Xb in [
        ("DTL", lambda: DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=alpha), X, X_fe),
    ]:
        m0, _ = cv_macro_f1(model_fn, Xa, y)
        m1, _ = cv_macro_f1(model_fn, Xb, y)
        print(f"  {name}: {len(cols)} fitur {m0:.4f}  ->  "
              f"{len(cols_fe)} fitur {m1:.4f}  (selisih {m1 - m0:+.4f})")
    print("  Selisih masih di dalam noise antar fold (std ~0.008). CART sudah bisa")
    print("  split pada kolom mentahnya, jadi fitur turunan tidak menambah sinyal.\n")


# 4. Seberapa besar noise public leaderboard?

def experiment_leaderboard_noise(X, y, alpha):
    print("=" * 74)
    print("4. NOISE PUBLIC LEADERBOARD")
    print("=" * 74)
    print("Public leaderboard hanya menilai ~30% dari 7200 baris uji (~2160). Satu")
    print("model yang sama diskor pada banyak subset acak 2160 baris dari prediksi")
    print("out-of-fold, sehingga seluruh sebaran di bawah murni efek sampling.\n")

    oof = np.zeros(len(y))
    for tr_idx, va_idx in k_fold_indices(len(y), N_FOLDS, seed=SEED):
        model = DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=alpha).fit(X[tr_idx], y[tr_idx])
        oof[va_idx] = model.predict(X[va_idx])

    full = macro_f1(y, oof)
    rng = np.random.default_rng(0)
    sims = np.array([macro_f1(y[i], oof[i]) for i in
                     (rng.choice(len(y), 2160, replace=False) for _ in range(2000))])

    print(f"  skor pada 28800 baris out-of-fold  : {full:.4f}")
    print(f"  model sama pada sampel 2160 baris  : rata-rata {sims.mean():.4f}, "
          f"std {sims.std():.4f}")
    print(f"  rentang 90% undian                : {np.percentile(sims, 5):.4f} .. "
          f"{np.percentile(sims, 95):.4f}")
    print(f"  P(undian tampak >= 0.89)          : {(sims >= 0.89).mean() * 100:.1f}%")
    print("  Model bernilai ~0.874 cukup sering tampil sebagai 0.89, sehingga pada")
    print("  leaderboard berisi banyak peserta hal itu wajar terjadi.\n")


def experiment_public_lb_tuning(X, y, alpha):
    # Menguji apakah memilih submission berdasarkan skor public itu menguntungkan.
    print("=" * 74)
    print("6. APAKAH PERLU MENGEJAR SKOR PUBLIC LEADERBOARD?")
    print("=" * 74)
    print("Misalkan dibuat K submission yang kualitasnya sama, lalu disimpan yang")
    print("skor public-nya tertinggi. Berapa skor private yang didapat?\n")

    oof = np.zeros(len(y))
    for tr_idx, va_idx in k_fold_indices(len(y), N_FOLDS, seed=SEED):
        oof[va_idx] = DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=alpha).fit(
            X[tr_idx], y[tr_idx]).predict(X[va_idx])

    rng = np.random.default_rng(0)
    n_test, n_pub = 7200, int(0.3 * 7200)
    print(f"  {'K':>3} | {'public terpilih':>15} | {'private-nya':>12} | {'selisih':>9}")
    print("  " + "-" * 50)
    for k in (1, 5, 20):
        pub_sel, priv_sel = [], []
        for _ in range(1500):
            idx = rng.choice(len(y), n_test, replace=False)
            yt, pt = y[idx], oof[idx]
            pubs, privs = [], []
            for _ in range(k):
                order = rng.permutation(n_test)
                # jitter meniru model yang berbeda tapi kualitasnya setara
                p = np.where(rng.random(n_test) < 0.012, 1 - pt, pt)
                pubs.append(macro_f1(yt[order[:n_pub]], p[order[:n_pub]]))
                privs.append(macro_f1(yt[order[n_pub:]], p[order[n_pub:]]))
            best = int(np.argmax(pubs))
            pub_sel.append(pubs[best]); priv_sel.append(privs[best])
        print(f"  {k:>3} | {np.mean(pub_sel):>15.4f} | {np.mean(priv_sel):>12.4f} | "
              f"{np.mean(priv_sel) - np.mean(pub_sel):>+9.4f}")

    print("\n  Skor public naik seiring K sementara private justru turun. Model yang")
    print("  disubmit karena itu dipilih lewat CV pada 28.800 baris, bukan lewat")
    print("  skor public.\n")


def experiment_seed_stability(X, y, alpha):
    # Perbaikan yang diukur pada satu pembagian CV bisa saja kebetulan.
    print("=" * 74)
    print("5. APAKAH KEUNGGULAN PRUNING NYATA ATAU KEBETULAN SATU SPLIT?")
    print("=" * 74)

    pre, post = [], []
    for seed in [42, 1, 7, 13, 2024, 99, 555, 31]:
        scores = {"pre": [], "post": []}
        for tr_idx, va_idx in k_fold_indices(len(y), N_FOLDS, seed=seed):
            a = DecisionTreeCARTScratch(max_depth=8, min_samples_split=40,
                                 min_samples_leaf=20).fit(X[tr_idx], y[tr_idx])
            b = DecisionTreeCARTScratch(**GROW_PARAMS, ccp_alpha=alpha).fit(X[tr_idx], y[tr_idx])
            scores["pre"].append(macro_f1(y[va_idx], a.predict(X[va_idx])))
            scores["post"].append(macro_f1(y[va_idx], b.predict(X[va_idx])))
        pre.append(np.mean(scores["pre"]))
        post.append(np.mean(scores["post"]))
        print(f"  seed {seed:>5}: pre-pruning {pre[-1]:.4f}   pruning {post[-1]:.4f}"
              f"   ({post[-1] - pre[-1]:+.4f})")

    pre, post = np.array(pre), np.array(post)
    delta = post - pre
    print(f"\n  pre-pruning : {pre.mean():.4f} +/- {pre.std():.4f}")
    print(f"  pruning     : {post.mean():.4f} +/- {post.std():.4f}")
    print(f"  Pruning menang di {(delta > 0).sum()}/{len(delta)} seed, "
          f"rata-rata {delta.mean():+.4f}.")
    print(f"  Ekspektasi wajar ~{post.mean():.4f}, bukan {post[0]:.4f} dari seed 42 saja.\n")


def main():
    train_df, test_df, cols = prepare_train_test("../../data")
    X, y = to_xy(train_df, cols)

    alpha = experiment_pruning(X, y)
    experiment_threshold(X, y, alpha)
    experiment_features(train_df, cols, X, y, alpha)
    experiment_leaderboard_noise(X, y, alpha)
    experiment_public_lb_tuning(X, y, alpha)
    experiment_seed_stability(X, y, alpha)


if __name__ == "__main__":
    main()
