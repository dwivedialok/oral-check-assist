#!/usr/bin/env python3
"""
Gated fusion policy: combines binary and 5-class ONNX ensembles with OOD gate and
configurable risk fusion (max or weighted) and referral threshold.

Usage:
  from fusion_policy import GatedFusionPolicy
  policy = GatedFusionPolicy(binary_onnx_dir, fiveclass_onnx_dir, config)
  out = policy.predict(image_path)
  # out["action"] in ("refer", "no_refer", "retake")
"""

import sys
from pathlib import Path

import numpy as np

try:
    import onnxruntime as ort
except ImportError:
    ort = None

NOTEBOOK_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(NOTEBOOK_DIR))

from evaluate_on_frozen_sets import (
    load_and_preprocess_image_onnx_ensemble,
    ENSEMBLE_WEIGHTS,
    CANCER_CLASS_INDICES,
)

FIVECLASS_CLASS_NAMES = ["Benign", "Healthy", "OCA", "OPMD", "Unknown"]
UNKNOWN_INDEX = 4
OCA_INDEX = 2
OPMD_INDEX = 3


class GatedFusionPolicy:
    """
    Policy: (1) OOD gate on 5-class Unknown -> retake
            (2) risk5 = p(OPMD)+p(OCA), riskB = p_bin(cancer)
            (3) risk = max(riskB, risk5) or w*riskB + (1-w)*risk5
            (4) refer if risk >= referral_threshold
    """

    DEFAULT_CONFIG = {
        "ood_unknown_threshold": 0.6,
        "fusion": "max",  # "max" or "weighted"
        "fusion_weight_binary": 0.5,  # w for weighted: risk = w*riskB + (1-w)*risk5
        "referral_threshold": 0.35,
        "image_size": (224, 224),
    }

    def __init__(self, binary_onnx_dir, fiveclass_onnx_dir, config=None):
        if ort is None:
            raise RuntimeError("onnxruntime is required")
        self.config = {**self.DEFAULT_CONFIG, **(config or {})}
        self.binary_onnx_dir = Path(binary_onnx_dir)
        self.fiveclass_onnx_dir = Path(fiveclass_onnx_dir)
        self._load_sessions()

    def _load_sessions(self):
        names = ["ensemble_model_1.onnx", "ensemble_model_2.onnx", "ensemble_model_3.onnx"]
        self._bin_sessions = []
        self._five_sessions = []
        self._bin_input_name = None
        self._five_input_name = None
        for name in names:
            s = ort.InferenceSession(str(self.binary_onnx_dir / name))
            self._bin_sessions.append(s)
            if self._bin_input_name is None:
                self._bin_input_name = s.get_inputs()[0].name
        for name in names:
            s = ort.InferenceSession(str(self.fiveclass_onnx_dir / name))
            self._five_sessions.append(s)
            if self._five_input_name is None:
                self._five_input_name = s.get_inputs()[0].name

    def _run_binary(self, image_path):
        arr = load_and_preprocess_image_onnx_ensemble(
            image_path, self.config["image_size"]
        )
        all_out = []
        for sess, w in zip(self._bin_sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {self._bin_input_name: arr})[0]
            all_out.append(out * w)
        logits = np.sum(all_out, axis=0)[0]
        exp = np.exp(logits - np.max(logits))
        probs = exp / exp.sum()
        return float(probs[1])

    def _run_fiveclass(self, image_path):
        arr = load_and_preprocess_image_onnx_ensemble(
            image_path, self.config["image_size"]
        )
        all_out = []
        for sess, w in zip(self._five_sessions, ENSEMBLE_WEIGHTS):
            out = sess.run(None, {self._five_input_name: arr})[0]
            all_out.append(out * w)
        logits = np.sum(all_out, axis=0)[0]
        exp = np.exp(logits - np.max(logits))
        probs = exp / exp.sum()
        risk5 = float(probs[OCA_INDEX] + probs[OPMD_INDEX])
        unknown_prob = float(probs[UNKNOWN_INDEX])
        pred_idx = int(np.argmax(logits))
        label = FIVECLASS_CLASS_NAMES[pred_idx]
        confidence = float(np.max(probs))
        return {
            "probs": probs,
            "risk5": risk5,
            "unknown_prob": unknown_prob,
            "p_oca": float(probs[OCA_INDEX]),
            "p_opmd": float(probs[OPMD_INDEX]),
            "label": label,
            "confidence": confidence,
        }

    def predict(self, image_path):
        """
        Returns dict with action in ("refer", "no_refer", "retake"), risk_score, risk5, riskB,
        fiveclass_label, confidence.
        """
        path = Path(image_path)
        if not path.exists():
            return {
                "action": "retake",
                "risk_score": 0.0,
                "risk5": 0.0,
                "riskB": 0.0,
                "fiveclass_label": "Unknown",
                "confidence": 0.0,
                "error": "file_not_found",
            }
        riskB = self._run_binary(path)
        five = self._run_fiveclass(path)
        risk5 = five["risk5"]
        unknown_prob = five["unknown_prob"]
        ood_thresh = self.config["ood_unknown_threshold"]
        if five["label"] == "Unknown" and unknown_prob > ood_thresh:
            return {
                "action": "retake",
                "risk_score": 0.0,
                "risk5": risk5,
                "riskB": riskB,
                "fiveclass_label": five["label"],
                "confidence": five["confidence"],
            }
        fusion = self.config["fusion"]
        w = self.config.get("fusion_weight_binary", 0.5)
        if fusion == "max":
            risk = max(riskB, risk5)
        else:
            risk = w * riskB + (1 - w) * risk5
        ref_thresh = self.config["referral_threshold"]
        action = "refer" if risk >= ref_thresh else "no_refer"
        return {
            "action": action,
            "risk_score": float(risk),
            "risk5": risk5,
            "riskB": riskB,
            "fiveclass_label": five["label"],
            "confidence": five["confidence"],
        }


def current_dart_decision_matrix(cancer_prob, p_oca, p_opmd, p_unknown, fiveclass_label):
    """
    Replicate Dart decision matrix for comparison.
    Returns risk_level in (0=low, 1=moderate, 2=high); referral = (risk_level >= 1).
    """
    LOW, MODERATE, HIGH = 0, 1, 2
    low_ref = 0.31
    high_ref = 0.54
    oca_high = 0.55
    oca_low = 0.4
    opmd_th = 0.45
    if cancer_prob < low_ref:
        risk = LOW
    elif cancer_prob < high_ref:
        risk = MODERATE
    else:
        risk = HIGH
    if p_oca >= oca_high and risk < HIGH:
        risk = HIGH
    elif p_oca >= oca_low and risk != LOW:
        risk = HIGH
    elif p_opmd >= opmd_th and risk == LOW:
        risk = MODERATE
    return risk


def get_referral_from_dart_risk(risk_level):
    """Referral = moderate or high (risk_level >= 1)."""
    return risk_level >= 1
