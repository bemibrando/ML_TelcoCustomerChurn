# Project Roadmap — Telco Customer Churn

The lifecycle of the project: what has been done, what is missing, and what "done" means for
each phase. Update the checkboxes as work progresses.

**Status legend:** ✅ Done · 🟡 Partial · ⬜ Not started

| #  | Phase                              | Status | Main deliverable                                  |
|----|------------------------------------|--------|---------------------------------------------------|
| 1  | ML Canvas                          | ✅     | `docs/ml_canvas.html`, `docs/ml_canvas.json`      |
| 2  | Data Discovery                     | 🟡     | `docs/data_discovery.md`                          |
| 3  | Data Contract                      | ⬜     | `contracts/telco_customer.yaml` + validation code |
| 4  | Data Pipeline                      | 🟡     | `src/telco_churn/data/`                           |
| 5  | EDA                                | ✅     | `notebooks/01_exploratory_data_analysis.ipynb`    |
| 6  | Feature Engineering                | 🟡     | `src/telco_churn/features/`                       |
| 7  | Experimentation                    | ⬜     | `notebooks/02_*`, MLflow experiments              |
| 8  | Model Selection                    | ⬜     | `docs/model_card.md`                              |
| 9  | CI/CD                              | ⬜     | `.github/workflows/`                              |
| 10 | Model Registry                     | ⬜     | MLflow Model Registry                             |
| 11 | Deploy                             | ⬜     | FastAPI service + Docker image                    |
| 12 | Monitoring                         | ⬜     | Metrics/drift reports, alerts                     |
| 13 | Drift & Retraining                 | ⬜     | Retraining pipeline + trigger rules               |

### Target structure

```
telco-customer-churn/
├── .github/workflows/        # CI/CD (phase 9)
├── contracts/                # data contract (phase 3)
├── data/{raw,interim,processed}/
├── docs/                     # canvas, discovery, model card, roadmap
├── models/                   # local artifacts (registry is the source of truth)
├── notebooks/                # 01_eda, 02_baselines, 03_mlp, ...
├── reports/                  # profiling, evaluation, drift reports
├── src/telco_churn/
│   ├── config.py
│   ├── data/                 # ingest, validate, clean, split
│   ├── features/             # transformers + sklearn pipeline
│   ├── models/               # baselines, MLP (PyTorch), train, evaluate
│   ├── api/                  # FastAPI app
│   └── monitoring/           # drift + performance checks
└── tests/
```

---

## 1. ML Canvas ✅

**Goal:** agree on the problem, metrics, data, and production design before writing code.

- [x] Business problem, stakeholders, KPIs (Churn Rate, LTV, conversion, cost of churn avoided)
- [x] Error trade-off: false negatives are costlier, so recall on the churn class comes first
- [x] Technical targets: **recall > 70%, precision > 60%, AUC > 80%**
- [x] Model plan: PyTorch MLP, with DummyClassifier and Logistic Regression as baselines
- [x] Production design: FastAPI, Docker, MLflow, monitoring, retraining
- [ ] Answer the open business questions (they feed threshold and cost decisions):
  - [x] Current churn rate → **26.6%** (from EDA)
  - [ ] Cost of losing a customer (use CLTV / monthly charges as a proxy)
  - [ ] How many customers can the retention team reach per month (capacity → top-K / threshold)
  - [ ] Ideal lead time between prediction and churn
- [ ] Define the cost matrix (cost of FN vs. FP) for cost-sensitive learning

---

## 2. Data Discovery 🟡

**Goal:** know where the data comes from, what each column means, and what it can be used for.

- [x] Source identified: IBM Telco Customer Churn (Kaggle `yeanzc/telco-customer-churn-ibm-dataset`)
- [x] Data dictionary written in the EDA (section 4)
- [x] Sanity checks: types, nulls, `Total Charges` stored as text
- [ ] Write `docs/data_discovery.md`: source, licence, row count, granularity (1 row = 1 customer),
      snapshot date, refresh frequency in production
- [ ] Script the download (`kaggle` CLI) so `data/raw/` can be rebuilt from scratch
- [ ] **Leakage audit**: classify every column as *available at prediction time* or not.
      Candidates to drop: `Churn Label`, `Churn Score`, `Churn Reason`, `CLTV` (to be confirmed)
- [ ] Note PII and identifiers (`CustomerID`, `Lat Long`, `Zip Code`) and how they are handled

**Done when:** every column has a meaning, an owner/source, and a leakage verdict.

---

## 3. Data Contract ⬜

**Goal:** a machine-checkable agreement on what valid input data looks like, for training and for
the API.

- [ ] Create `contracts/telco_customer.yaml` with, for each column: name, type, nullable, allowed
      values/ranges (e.g. `tenure_months >= 0`, `contract ∈ {Month-to-month, One year, Two year}`)
- [ ] Define the primary key (`customer_id`) and uniqueness rule
- [ ] Define freshness/volume expectations (e.g. ≥ 5,000 rows, as in the canvas)
- [ ] Implement validation (`pandera` or `great_expectations`) in `src/telco_churn/data/validate.py`
- [ ] Reuse the same schema for the API request model (Pydantic) so training and serving agree
- [ ] Decide versioning: a breaking schema change bumps the contract version
- [ ] Tests: valid sample passes; out-of-range/missing/unknown-category samples fail

**Done when:** the pipeline refuses data that breaks the contract and says why.

---

## 4. Data Pipeline 🟡

**Goal:** move the notebook's data preparation into reproducible, tested code:
`raw → interim → processed`.

Already in the notebook (section 20): drop non-informative columns, convert `Total Charges` to
numeric, snake_case names, save to `data/interim/` and `data/processed/`.

- [ ] `ingest.py`: download/read `Telco_customer_churn.xlsx` → `data/raw/`
- [ ] `clean.py`: move the notebook cleaning steps; handle `Total Charges` nulls (new customers)
- [ ] `split.py`: **stratified train/validation/test split on the real (unbalanced) data**, with a fixed seed
- [ ] Save splits as Parquet in `data/processed/`
- [ ] One entry point: `python -m telco_churn.data.make_dataset` (or `make data`)
- [ ] Consider DVC for data versioning (optional)
- [ ] Unit tests for each step

**Done when:** one command rebuilds every dataset from the raw file, with the same output each time.

---

## 5. EDA ✅

**Goal:** understand churn drivers and data quality. Done in
`notebooks/01_exploratory_data_analysis.ipynb`.

- [x] Univariate, bivariate, geographic, financial, CLTV, churn reason analysis
- [x] Correlation, VIF, Information Value, Chi-square + Cramér's V
- [x] Decision-tree feature importance → churn drivers in tiers
- [x] Conclusions and feature engineering suggestions
- [ ] Run the notebook end to end and commit it with outputs (or export an HTML report to `reports/`)
- [ ] Summarise the key findings in the README

**Key findings to carry forward:** churn 26.6%; tenure, contract, internet service, online
security and tech support are the top drivers; `City` needs grouping; `Churn Score`/`CLTV` may
leak; `Total Charges`, `Tenure Months`, `Monthly Charges`, `CLTV`, `Churn Score` have high VIF.

---

## 6. Feature Engineering 🟡

**Goal:** a scikit-learn `Pipeline`/`ColumnTransformer` that is fitted on training data only and
reused unchanged at inference.

Suggested in the EDA (section 19), not built yet:

- [ ] Group `City` into regions/clusters (avoid rare categories)
- [ ] Digital-engagement score (count of online services)
- [ ] `tenure_group` (new vs. long-tenured customers)
- [ ] Cost-perception proxy (e.g. `monthly_charges / services_count`)
- [ ] Ordinal encoding of `contract` (Month-to-month < One year < Two year)
- [ ] Family-stability flag (partner/dependents)
- [ ] Handle multicollinearity (drop `total_charges` or keep it only for tree models)
- [ ] One-hot encoding for nominal categories, scaling for numeric (required for the MLP and Logistic Regression)
- [ ] Wrap it all in `build_preprocessor()` in `src/telco_churn/features/`
- [ ] Save the fitted preprocessor together with the model (same artifact)
- [ ] Tests: output shape, no NaNs, unseen categories handled

**Done when:** `preprocessor.fit(X_train)` → `transform(X_any)` works and is part of the model artifact.

---

## 7. Experimentation ⬜

**Goal:** compare models fairly and log everything in MLflow.

- [ ] Add dependencies: `torch`, `mlflow`, (`optuna` for tuning)
- [ ] Set up the MLflow tracking server (local `mlruns/` or docker-compose service)
- [ ] Baseline 1: `DummyClassifier` (lower bound)
- [ ] Baseline 2: `LogisticRegression` with `class_weight="balanced"`
- [ ] Optional extra baseline: a tree ensemble (Random Forest / XGBoost / LightGBM)
- [ ] Main model: PyTorch MLP (architecture, dropout, early stopping, `pos_weight` in the loss)
- [ ] Handle imbalance with class weights / cost-sensitive loss, compared against resampling *inside* CV only
- [ ] Stratified k-fold cross-validation
- [ ] Hyperparameter tuning (Optuna), logged to MLflow
- [ ] Log per run: params, ROC-AUC, PR-AUC, recall, precision, F1, confusion matrix, ROC/PR curves
- [ ] Fix all random seeds for reproducibility

**Done when:** every candidate has an MLflow run with comparable metrics on the same splits.

---

## 8. Model Selection ⬜

**Goal:** pick the model and threshold that meet the business targets.

- [ ] Threshold tuning on the validation set to reach recall > 70% while keeping precision > 60%
- [ ] Choose by expected cost (cost matrix from phase 1), not only by AUC
- [ ] Probability calibration (Platt / isotonic) if scores drive the 0.7 CRM rule
- [ ] Final evaluation **once** on the held-out test set
- [ ] Check the targets: recall > 70%, precision > 60%, AUC > 80%
- [ ] Explainability: SHAP or permutation importance; compare with the EDA drivers
- [ ] Fairness check across `gender` and `senior_citizen`
- [ ] Business view: lift/gain curve, top-decile capture, estimated revenue saved (~US$ 14k/month goal)
- [ ] Write `docs/model_card.md` (data, metrics, threshold, limitations, intended use)

**Done when:** a chosen model + threshold, test metrics that meet the targets, and a model card.

---

## 9. CI/CD ⬜

**Goal:** every change is linted, tested and (on main) built and shipped automatically.

- [ ] Fix the `Dockerfile` `CMD` (it has Jupyter flags but no `jupyter` command); split into a dev image and an API image
- [ ] Rename the package in `pyproject.toml` (`project-eda` → `telco-churn`) and use a `src/` layout
- [ ] Pre-commit hooks: `ruff`, `black`, `nbstripout`
- [ ] GitHub Actions — **CI** on every PR: install, lint, `pytest`, data-contract tests
- [ ] Add a small model check to CI: train on a sample, fail if AUC drops below a floor
- [ ] GitHub Actions — **CD** on merge to main: build and push the API Docker image, deploy
- [ ] Pin dependency versions (lock file) for reproducible builds

**Done when:** a PR cannot be merged with failing lint/tests, and main builds a deployable image.

---

## 10. Model Registry ⬜

**Goal:** one source of truth for which model version is in production.

- [ ] Register the selected model (preprocessor + model + threshold) in the MLflow Model Registry
- [ ] Use aliases: `challenger` (new candidate) and `champion` (in production)
- [ ] Attach to each version: metrics, data/contract version, git commit, model card
- [ ] Promotion rule: challenger becomes champion only if it beats champion on the same test set
- [ ] Rollback procedure: point `champion` back to the previous version

**Done when:** the API loads `models:/telco-churn@champion`, never a loose local file.

---

## 11. Deploy ⬜

**Goal:** serve churn predictions to the CRM over a REST API.

- [ ] FastAPI app in `src/telco_churn/api/`
  - [ ] `POST /predict` → `{churn_probability, churn_label, threshold, model_version}`
  - [ ] `POST /predict/batch` for CRM batch scoring
  - [ ] `GET /health` and `GET /model-info`
- [ ] Pydantic request schema matching the data contract
- [ ] Load the model from the registry at startup
- [ ] Log every request/prediction (inputs, output, version, timestamp) for monitoring
- [ ] API Docker image + `docker-compose` service (API + MLflow)
- [ ] API tests (`TestClient`): valid request, invalid request, response format
- [ ] Choose a deployment target (Render, Railway, Cloud Run, Azure Container Apps, ...)
- [ ] Document the activation rule for the CRM: churn probability > 0.7 → retention action

**Done when:** `curl` to the deployed `/predict` returns a probability from the champion model.

---

## 12. Monitoring ⬜

**Goal:** know when the model or the data stops behaving as expected.

- [ ] Store prediction logs (file/DB) from the API
- [ ] Service metrics: latency, error rate, request volume
- [ ] Data quality: contract violations, nulls, unseen categories in live data
- [ ] Prediction drift: distribution of churn probabilities over time
- [ ] Performance: once real churn labels arrive, compute recall, precision, AUC per period
- [ ] Reports with Evidently (HTML in `reports/monitoring/`) or a Grafana dashboard
- [ ] Alerts: e.g. recall < 70% or AUC < 80% → notify

**Done when:** a scheduled job produces a monitoring report and raises alerts on threshold breaches.

---

## 13. Drift & Retraining ⬜

**Goal:** detect data and concept drift, then retrain and redeploy safely.

- [ ] **Data drift**: PSI / KS test per feature against the training reference (e.g. PSI > 0.2 → alert)
- [ ] **Concept drift**: performance drop on newly labelled data
- [ ] Retraining pipeline: `ingest → validate → features → train → evaluate → register as challenger`
- [ ] Triggers: scheduled (monthly, per the canvas) **or** drift/performance alert
- [ ] Automatic comparison of challenger vs. champion; promote only if better (phase 10)
- [ ] Orchestrate with a scheduled GitHub Action (or Prefect/Airflow)
- [ ] Keep the history: which data, which version, why it was retrained

**Done when:** a drift alert can produce a new registered challenger without manual steps.

---

## Issues found in the current code

Fix these before or during phases 4–8:

1. **Leakage in the selected features** — `df_selected` (EDA §20.5) keeps `churn_reason`, which
   is only filled in for customers who already left. It must be removed from the model inputs.
2. **Balancing before splitting** — the notebook undersamples the full dataset (§20.3). If
   train/test are cut from `df_balanced`, the test set is artificially 50/50 and metrics will be
   too optimistic. Split first; balance (or weight) only the training data.
3. **Undersampling throws data away** — with ~7k rows, prefer class weights / cost-sensitive loss
   (matches the canvas plan) and compare.
4. **`Churn Score` and `CLTV`** — flagged in the EDA as possible leakage; confirm before use.
5. **Dockerfile `CMD`** — starts with `--ip=...` but no `jupyter` command, so the container would
   fail without the `sleep infinity` override in `docker-compose.yml`.
6. **Notebook outputs are cleared** — not yet confirmed that it runs end to end.
7. **No README** — add an overview, setup instructions, and a link to this roadmap.

---

## Suggested order

1. Fix issues 1–2, write the leakage audit (phase 2)
2. Data pipeline + data contract (phases 3–4)
3. Feature pipeline (phase 6)
4. Baselines in MLflow → MVP (phase 7) — *this is the open "Next Step" from the EDA*
5. MLP + threshold tuning + model selection (phases 7–8)
6. CI (phase 9), registry (phase 10), API + deploy (phase 11)
7. Monitoring, drift, retraining (phases 12–13)
