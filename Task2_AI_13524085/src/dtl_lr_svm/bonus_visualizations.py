"""Visualisasi bonus: percabangan decision tree, kurva loss Logistic Regression,
serta kontur loss dan lintasan parameternya.

    python bonus_visualizations.py
"""
import os

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from data import prepare_train_test, to_xy, fit_standardizer, standardize
from algoritma.decision_tree import DecisionTreeCARTScratch
from algoritma.logistic_regression import LogisticRegressionScratch, _sigmoid

SEED = 42

# Gambar disimpan di pic/ sebelah skrip ini, apa pun direktori kerja saat dijalankan.
PIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pic")


def _save(fig, filename, dpi=150, **kwargs):
    os.makedirs(PIC_DIR, exist_ok=True)
    path = os.path.join(PIC_DIR, filename)
    fig.savefig(path, dpi=dpi, **kwargs)
    plt.close(fig)
    print(f"pic/{filename} disimpan.")


# 1) Diagram percabangan decision tree

def _layout(node, depth=0, next_slot=None):
    """Menentukan koordinat (x, y) tiap node.

    Leaf mengisi slot x berurutan dari kiri ke kanan dan tiap parent diletakkan
    tepat di tengah anak-anaknya, sehingga cabang tidak pernah bertumpuk dan
    tidak ada ruang kosong yang menganga.
    """
    if next_slot is None:
        next_slot = [0]

    node["y"] = -depth
    if node["leaf"]:
        node["x"] = next_slot[0]
        next_slot[0] += 1
    else:
        _layout(node["left"], depth + 1, next_slot)
        _layout(node["right"], depth + 1, next_slot)
        node["x"] = (node["left"]["x"] + node["right"]["x"]) / 2.0
    return node


def _walk(node):
    yield node
    if not node["leaf"]:
        yield from _walk(node["left"])
        yield from _walk(node["right"])


def _pretty(name):
    # Pendekkan nama kolom hasil encoding supaya muat di dalam kotak node.
    return (name.replace("person_home_ownership_", "home=")
                .replace("previous_loan_defaults_on_file", "prev_defaults")
                .replace("cb_person_cred_hist_length", "cred_hist_length"))


def plot_tree(root, ax, total_n):
    # Garis digambar dulu supaya kotak node berada di atasnya.
    for node in _walk(root):
        if node["leaf"]:
            continue
        for child, label, colour in ((node["left"], "ya", "#1a7f37"),
                                     (node["right"], "tidak", "#b42318")):
            ax.annotate("", xy=(child["x"], child["y"] + 0.30),
                        xytext=(node["x"], node["y"] - 0.30),
                        arrowprops=dict(arrowstyle="-", color="#9aa0a6", lw=1.2))
            ax.text((node["x"] + child["x"]) / 2, (node["y"] + child["y"]) / 2,
                    label, fontsize=7.5, color=colour, ha="center", va="center",
                    bbox=dict(boxstyle="round,pad=0.18", fc="white", ec="none"))

    cmap = plt.get_cmap("RdYlGn")
    for node in _walk(root):
        share = 100.0 * node["n"] / total_n
        if node["leaf"]:
            # Warna menyatakan p(disetujui): merah ditolak, hijau disetujui.
            ax.text(node["x"], node["y"],
                    f"p(setuju)={node['proba']:.2f}\nn={node['n']:,}  ({share:.0f}%)",
                    ha="center", va="center", fontsize=7.5,
                    bbox=dict(boxstyle="round,pad=0.42", linewidth=1.1,
                              fc=cmap(node["proba"]), ec="#5f6368", alpha=0.95))
        else:
            ax.text(node["x"], node["y"],
                    f"{_pretty(node['feature'])}\n$\\leq$ {node['threshold']:.2f} ?\n"
                    f"n={node['n']:,}  gini={node['gini']:.2f}",
                    ha="center", va="center", fontsize=7.5,
                    bbox=dict(boxstyle="round,pad=0.42", linewidth=1.1,
                              fc="#dbe9f6", ec="#2c3e6b"))


def make_tree_plot(X, y, cols):
    shallow = DecisionTreeCARTScratch(max_depth=3, min_samples_split=40, min_samples_leaf=20)
    shallow.fit(X, y, sample_weight=None)
    tree_dict = _layout(shallow.to_dict(cols))

    xs = [n["x"] for n in _walk(tree_dict)]
    ys = [n["y"] for n in _walk(tree_dict)]

    fig, ax = plt.subplots(figsize=(13, 6.5))
    plot_tree(tree_dict, ax, total_n=len(y))
    ax.set_xlim(min(xs) - 0.75, max(xs) + 0.75)
    ax.set_ylim(min(ys) - 0.6, max(ys) + 0.6)
    ax.axis("off")
    ax.set_title(
        "Decision Tree (CART) - 3 level teratas\n"
        "Split pertama yang ditemukan otomatis adalah prev_defaults, persis sesuai temuan EDA:\n"
        "cabang 'tidak' (riwayat gagal bayar = Yes) langsung berujung leaf p(setuju)=0.00",
        fontsize=10.5, linespacing=1.5)
    fig.tight_layout()
    _save(fig, "tree_plot.png", dpi=170, bbox_inches="tight")


# 2) Kurva loss training Logistic Regression (model dengan seluruh fitur)

def make_lr_loss_curve(X, y, cols):
    mean, std = fit_standardizer(X)
    Xs = standardize(X, mean, std)

    model = LogisticRegressionScratch(lr=0.5, n_epochs=800, l2=1e-3, record_history=True)
    model.fit(Xs, y, sample_weight=None)

    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.plot(model.loss_history)
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Weighted BCE loss + L2")
    ax.set_title("Logistic Regression - Kurva Loss Training (14 fitur)")
    fig.tight_layout()
    _save(fig, "lr_loss_curve.png")


# 3) Kontur loss dan lintasan parameter LR (model bantu 2 fitur)

def make_lr_contour(X, y, cols):
    # Dua fitur paling diskriminatif menurut EDA, supaya ruang bobot 2D-nya bermakna.
    f1, f2 = "previous_loan_defaults_on_file", "loan_percent_income"
    idx1, idx2 = cols.index(f1), cols.index(f2)
    X2 = X[:, [idx1, idx2]]
    mean, std = fit_standardizer(X2)
    X2s = standardize(X2, mean, std)

    model = LogisticRegressionScratch(lr=0.5, n_epochs=200, l2=1e-3, record_history=True)
    model.fit(X2s, y, sample_weight=None)
    path = np.array(model.weight_history)  # (epochs, 2)

    def loss_at(w1, w2):
        z = X2s[:, 0] * w1 + X2s[:, 1] * w2 + model.bias
        p = _sigmoid(z)
        eps = 1e-12
        bce = -(y * np.log(p + eps) + (1 - y) * np.log(1 - p + eps)).mean()
        return bce + 1e-3 * (w1 ** 2 + w2 ** 2)

    w1_range = np.linspace(path[:, 0].min() - 0.5, path[:, 0].max() + 0.5, 60)
    w2_range = np.linspace(path[:, 1].min() - 0.5, path[:, 1].max() + 0.5, 60)
    W1, W2 = np.meshgrid(w1_range, w2_range)
    Z = np.vectorize(loss_at)(W1, W2)

    fig, ax = plt.subplots(figsize=(7, 6))
    cs = ax.contourf(W1, W2, Z, levels=25, cmap="viridis")
    fig.colorbar(cs, ax=ax, label="Loss")
    ax.plot(path[:, 0], path[:, 1], color="red", marker=".", markersize=3, linewidth=1,
            label="Lintasan parameter (gradient descent)")
    ax.scatter([path[0, 0]], [path[0, 1]], color="white", edgecolor="black", zorder=5, label="start")
    ax.scatter([path[-1, 0]], [path[-1, 1]], color="orange", edgecolor="black", zorder=5, label="end")
    ax.set_xlabel(f"w[{f1}]")
    ax.set_ylabel(f"w[{f2}]")
    ax.set_title("Kontur Loss & Lintasan Parameter - LR 2 fitur\n"
                  f"({f1} vs {f2})")
    ax.legend()
    fig.tight_layout()
    _save(fig, "lr_loss_contour.png")


def main():
    train_df, test_df, cols = prepare_train_test("../../data")
    X, y = to_xy(train_df, cols)

    make_tree_plot(X, y, cols)
    make_lr_loss_curve(X, y, cols)
    make_lr_contour(X, y, cols)


if __name__ == "__main__":
    main()
