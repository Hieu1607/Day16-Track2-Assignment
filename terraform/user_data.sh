#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for LightGBM CPU benchmark"

sudo dnf update -y
sudo dnf install -y python3 python3-pip

pip3 install --upgrade pip
pip3 install lightgbm scikit-learn pandas numpy flask

mkdir -p /home/ec2-user/ml-benchmark

cat > /home/ec2-user/ml-benchmark/benchmark.py << 'EOF'
import time
import json
import numpy as np
import pandas as pd
import lightgbm as lgb
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, accuracy_score, f1_score, precision_score, recall_score

print("Generating synthetic dataset (10,000 samples, 20 features)...")
t0 = time.time()
X, y = make_classification(n_samples=10000, n_features=20, n_informative=15,
                            n_redundant=5, random_state=42)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
load_time = time.time() - t0
print(f"Data ready in {load_time:.2f}s")

train_data = lgb.Dataset(X_train, label=y_train)
params = {
    "objective": "binary",
    "metric": "auc",
    "num_leaves": 31,
    "learning_rate": 0.05,
    "n_jobs": -1,
    "verbose": -1,
}

print("Training LightGBM...")
t1 = time.time()
model = lgb.train(params, train_data, num_boost_round=100)
train_time = time.time() - t1
print(f"Training done in {train_time:.2f}s")

y_pred_prob = model.predict(X_test)
y_pred = (y_pred_prob > 0.5).astype(int)

auc    = roc_auc_score(y_test, y_pred_prob)
acc    = accuracy_score(y_test, y_pred)
f1     = f1_score(y_test, y_pred)
prec   = precision_score(y_test, y_pred)
rec    = recall_score(y_test, y_pred)

t2 = time.time()
for _ in range(1000):
    model.predict(X_test[:1])
inf_1000 = (time.time() - t2)
inf_1    = inf_1000 / 1000

result = {
    "load_time_s":        round(load_time, 4),
    "train_time_s":       round(train_time, 4),
    "best_iteration":     model.best_iteration,
    "auc_roc":            round(auc, 4),
    "accuracy":           round(acc, 4),
    "f1_score":           round(f1, 4),
    "precision":          round(prec, 4),
    "recall":             round(rec, 4),
    "inference_1row_ms":  round(inf_1 * 1000, 4),
    "inference_1000rows_s": round(inf_1000, 4),
}

print("\n=== Benchmark Results ===")
for k, v in result.items():
    print(f"  {k}: {v}")

with open("/home/ec2-user/ml-benchmark/benchmark_result.json", "w") as f:
    json.dump(result, f, indent=2)
print("\nSaved to benchmark_result.json")
EOF

cat > /home/ec2-user/ml-benchmark/server.py << 'EOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200

@app.route("/")
def index():
    return jsonify({"message": "LightGBM CPU benchmark server running"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
EOF

chown -R ec2-user:ec2-user /home/ec2-user/ml-benchmark

# Start Flask server for ALB health check
nohup python3 /home/ec2-user/ml-benchmark/server.py > /var/log/flask.log 2>&1 &

echo "Setup complete. Run: python3 /home/ec2-user/ml-benchmark/benchmark.py"
