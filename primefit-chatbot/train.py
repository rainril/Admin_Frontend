"""
Trains the intent classifier for the PrimeFit chatbot.

Model: TF-IDF (word + character n-grams) + Logistic Regression.
Chosen deliberately over a wrapped LLM API call — it's small, fast,
fully explainable (you can show feature weights per intent to a panel),
and trains in seconds on a laptop with no GPU.

Word n-grams capture phrase-level patterns ("cancel my ___").
Character n-grams capture sub-word patterns, which gives the model
some robustness to typos (e.g. "membershp" still shares 3-5 char
chunks with "membership") without needing a separate spellchecker.

Usage:
    python train.py
Outputs:
    model/intent_classifier.joblib   (vectorizer + classifier bundled together)
    model/label_report.txt           (accuracy / per-class precision-recall for your documentation)
"""

import os
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
from sklearn.pipeline import Pipeline, FeatureUnion
import joblib

DATA_PATH = os.path.join("data", "intents.csv")
MODEL_DIR = "model"
MODEL_PATH = os.path.join(MODEL_DIR, "intent_classifier.joblib")
REPORT_PATH = os.path.join(MODEL_DIR, "label_report.txt")


def build_pipeline():
    """
    FeatureUnion combines two views of the same text:
      - word n-grams (1-2 words): captures phrasing/intent structure
      - char n-grams (3-5 chars, word-boundary aware): captures sub-word
        patterns, so typos and shorthand ("membershp", "atendance") still
        overlap heavily with the correctly-spelled training examples
        instead of being treated as entirely unknown tokens.
    """
    word_vec = TfidfVectorizer(ngram_range=(1, 2), min_df=1)
    char_vec = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), min_df=1)

    return Pipeline([
        ("features", FeatureUnion([
            ("word", word_vec),
            ("char", char_vec),
        ])),
        ("clf", LogisticRegression(max_iter=1000)),
    ])


def main():
    os.makedirs(MODEL_DIR, exist_ok=True)

    df = pd.read_csv(DATA_PATH)
    print(f"Loaded {len(df)} training examples across {df['intent'].nunique()} intents.")

    X = df["text"]
    y = df["intent"]

    pipeline = build_pipeline()

    # With this few examples per intent, a held-out test split can't cover
    # every class (sklearn needs at least as many samples as classes for a
    # stratified split). As you add more training examples per intent
    # (recommended: 15-20+ each), this will switch to a real held-out report.
    try:
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        pipeline.fit(X_train, y_train)
        y_pred = pipeline.predict(X_test)
        report = classification_report(y_test, y_pred, zero_division=0)
    except ValueError:
        report = (
            "Dataset too small relative to number of intents for a held-out "
            "split (need more examples per intent for a real report).\n"
            "Training on the full dataset instead; add more labeled examples "
            "per intent (15-20+) to get a meaningful accuracy report."
        )

    print(report)
    with open(REPORT_PATH, "w") as f:
        f.write(report)

    # Retrain on the FULL dataset before saving, so the shipped model uses
    # every example you wrote (the split above is only for the report).
    pipeline.fit(X, y)
    joblib.dump(pipeline, MODEL_PATH)
    print(f"Saved model to {MODEL_PATH}")

    # Also save the intent -> role mapping learned from the data, so the
    # API can enforce permissions without a hardcoded dict going stale.
    role_map = df.groupby("intent")["role"].agg(lambda s: sorted(set(s))).to_dict()
    joblib.dump(role_map, os.path.join(MODEL_DIR, "intent_role_map.joblib"))
    print("Saved intent-role permission map.")


if __name__ == "__main__":
    main()