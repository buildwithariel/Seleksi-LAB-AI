# Task 2 - Seleksi Laboratorium Inteligensi Buatan (13524085)

Repository ini berisi dua bagian:

1. **Local Search** - spesifikasi & proof of concept untuk *Data Center Network Topology Design*:
   **keempat varian Hill-Climbing** (Steepest-Ascent, Sideways Move, Stochastic, Random Restart),
   Simulated Annealing, dan Genetic Algorithm.
2. **DTL, Logistic Regression, SVM** - implementasi from-scratch (numpy only) untuk
   [kompetisi Kaggle](https://www.kaggle.com/t/36d01a65f76c41699dde2d4a3ed33f83)
   *Loan Approval Classification*, dibandingkan dengan scikit-learn.

Dokumen spesifikasi lengkap + write-up ada di [`docs/Task2_AI_13524085.pdf`](docs/Task2_AI_13524085.pdf).

## Struktur Repository

```
Task2_AI_13524085/
├── data/                       # dataset Kaggle (tidak di-commit, lihat bagian Dataset)
├── src/
│   ├── local_search/           # PoC Local Search
│   │   ├── topology.py         # state, successor, objective function
│   │   ├── algorithms.py       # 4 varian Hill-Climbing, Simulated Annealing, GA
│   │   ├── main.py             # demo run
│   │   └── pic/                # gambar hasil run (grafik konvergensi)
│   └── dtl_lr_svm/              # implementasi DTL, LR, SVM
│       ├── algoritma/          # ketiga algoritma from scratch
│       │   ├── decision_tree.py        # CART + cost-complexity pruning
│       │   ├── logistic_regression.py
│       │   └── svm.py                  # SVM linear (Pegasos)
│       ├── data.py             # loading & preprocessing
│       ├── metrics.py          # macro F1 (from scratch)
│       ├── train.py            # CV, perbandingan vs sklearn, generate submission
│       ├── improve_experiments.py  # catatan eksperimen: pruning, threshold, FE, noise LB
│       ├── bonus_visualizations.py
│       ├── pic/                # gambar bonus (tree plot, LR loss curve & contour)
│       └── result/             # cv_summary.csv & submission.csv
├── notebooks/
│   ├── local_search/experiment.ipynb
│   └── dtl_lr_svm/experiment.ipynb
├── docs/
│   └── Task2_AI_13524085.pdf   # PDF gabungan spesifikasi + write-up
└── README.md
```

## Cara Menjalankan

Dependencies: `numpy`, `pandas`, `matplotlib`, `scikit-learn` (hanya untuk model pembanding),
`jupyter`.

```bash
pip install numpy pandas matplotlib scikit-learn jupyter
```

### Dataset

Isi `data/` (`train.csv`, `test.csv`, `sample_submission.csv`) diunduh dari halaman kompetisi
Kaggle dan sengaja **tidak** ikut di-commit, agar data kompetisi tidak diredistribusikan lewat
repo publik. Letakkan ketiga file tersebut di `data/` sebelum menjalankan bagian DTL/LR/SVM.

### Local Search PoC

```bash
cd src/local_search
python main.py
```

Mencetak initial state, final state, dan objective value dari **keenam** algoritma - empat varian
Hill-Climbing (Steepest-Ascent, Sideways Move, Stochastic, Random Restart), Simulated Annealing,
dan Genetic Algorithm - serta menyimpan grafik konvergensi ke `pic/objective_convergence.png`.

### DTL, LR, SVM

```bash
cd src/dtl_lr_svm
python train.py                  # 5-fold CV, perbandingan vs sklearn, generate result/submission.csv
python improve_experiments.py    # reproduksi seluruh eksperimen di write-up (berhasil & gagal)
python bonus_visualizations.py   # bonus: tree plot, LR loss curve, LR loss contour
```

Atau jalankan notebook interaktif di `notebooks/dtl_lr_svm/experiment.ipynb`.

### Submission Kaggle

`src/dtl_lr_svm/result/submission.csv` dihasilkan dari model from-scratch terbaik berdasarkan CV
(DTL/CART + cost-complexity pruning, macro F1 CV 0.8747). Skor public leaderboard: **0.85812**.

Model dipilih berdasarkan **cross-validation 28.800 baris**, bukan berdasarkan skor public
leaderboard yang hanya menilai ±2.160 baris (30% data uji). Ini disengaja: simulasi pada
`improve_experiments.py` menunjukkan bahwa memilih submission berdasarkan public score justru
**menurunkan** skor private - memilih yang terbaik dari 20 kandidat setara menaikkan public
+0.015 tapi menurunkan private -0.005 (*winner's curse*).

## Ringkasan Hasil

| Bagian | Hasil |
|---|---|
| Local Search | Keenam algoritma menurunkan cost topologi dari 2.7453 → 1.91-1.96, mencapai 0 bridge (fault-tolerant) & tetap connected. Terbaik: **HC Random Restart 1.9143**, mengungguli Simulated Annealing (1.9290) |
| DTL (CART + cost-complexity pruning) - scratch vs sklearn | **0.8747** vs 0.8745 (macro F1, 5-fold CV) |
| Logistic Regression - scratch vs sklearn | 0.8466 vs 0.8467 |
| SVM (Pegasos) - scratch vs sklearn | 0.8456 vs 0.8470 |

Dua perbaikan yang terbukti lewat CV: **cost-complexity pruning** pada CART (0.8701 → 0.8747,
tree mengecil dari 60 → 34 leaf) dan **`log1p`** pada kolom uang yang sangat skewed (LR & SVM
masing-masing +0.005). Empat pendekatan lain diuji dan gagal (class weighting, threshold tuning,
feature engineering turunan, SVM kernel RBF) - semuanya terdokumentasi dengan angkanya di
write-up dan dapat direproduksi lewat `improve_experiments.py`.

Detail lengkap (spesifikasi Local Search, metodologi, bug yang ditemukan, percobaan yang gagal)
ada di [`docs/Task2_AI_13524085.pdf`](docs/Task2_AI_13524085.pdf).
