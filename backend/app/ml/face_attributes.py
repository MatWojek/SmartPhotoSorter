from __future__ import annotations
from typing import Optional, Tuple

import cv2
import numpy as np


Box = Tuple[int, int, int, int]  # (x, y, w, h)


def _crop_safe(img: np.ndarray, x0: int, y0: int, x1: int, y1: int) -> Optional[np.ndarray]:
    h, w = img.shape[:2]
    x0 = max(0, min(w, x0))
    x1 = max(0, min(w, x1))
    y0 = max(0, min(h, y0))
    y1 = max(0, min(h, y1))
    if x1 <= x0 or y1 <= y0:
        return None
    region = img[y0:y1, x0:x1]
    if region.size == 0 or region.shape[0] < 5 or region.shape[1] < 5:
        return None
    return region


def extract_hair_color(img: np.ndarray, box: Box) -> Optional[str]:
    """A very simple heuristic for hair color based on the fragment above the face."""
    x, y, w, h = box

    # hair region: the strip above the face
    y1 = y
    y0 = int(y - 0.4 * h)
    x0, x1 = x, x + w

    region = _crop_safe(img, x0, y0, x1, y1)
    if region is None:
        return None

    hsv = cv2.cvtColor(region, cv2.COLOR_RGB2HSV)
    h_ch, s_ch, v_ch = cv2.split(hsv)

    # discard very bright/low saturated pixels (background, light)
    mask = (v_ch > 40) & (s_ch > 30)
    if not np.any(mask):
        return None

    h_vals = h_ch[mask].astype(np.float32)
    s_vals = s_ch[mask].astype(np.float32)
    v_vals = v_ch[mask].astype(np.float32)

    h_mean = float(np.mean(h_vals))
    s_mean = float(np.mean(s_vals))
    v_mean = float(np.mean(v_vals))

    # simple HSV map -> category
    if v_mean < 60:          # very dark
        return "black"
    if v_mean > 180 and s_mean < 80:
        return "blond"
    if 5 <= h_mean <= 25 and s_mean > 80:
        return "red"
    if v_mean > 80 and s_mean > 40:
        return "brown"
    if v_mean > 160 and s_mean < 60:
        return "gray"
    return "unknown"


def extract_eye_color(img: np.ndarray, box: Box) -> Optional[str]:
    """Simple eye color heuristic for a mid-face fragment."""
    x, y, w, h = box

    # middle stripe of the face ~ eye line
    y0 = int(y + 0.3 * h)
    y1 = int(y + 0.45 * h)
    x0 = int(x + 0.2 * w)
    x1 = int(x + 0.8 * w)

    region = _crop_safe(img, x0, y0, x1, y1)
    if region is None:
        return None

    hsv = cv2.cvtColor(region, cv2.COLOR_RGB2HSV)
    h_ch, s_ch, v_ch = cv2.split(hsv)

    # Skin/Noise Rejection: Moderate Brightness and Saturation
    mask = (v_ch > 40) & (v_ch < 220) & (s_ch > 20)
    if not np.any(mask):
        return None

    h_vals = h_ch[mask].astype(np.float32)
    s_vals = s_ch[mask].astype(np.float32)

    h_mean = float(np.mean(h_vals))
    s_mean = float(np.mean(s_vals))

    if s_mean < 25:
        return "dark"

    # map H (0–180)
    if 90 <= h_mean <= 140:
        return "blue"
    if 35 <= h_mean <= 90:
        return "green"
    if (10 <= h_mean <= 35) or (h_mean < 10 or h_mean > 160):
        return "brown"
    if 35 <= h_mean <= 60 and s_mean > 60:
        return "hazel"

    return "unknown"