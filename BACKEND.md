# GestureCtrl — Backend Documentation

A technical reference for the Python ML service (`ml/gesture_service.py`) that powers real-time hand gesture detection and desktop control.

---

## Table of Contents

1. [Overview](#overview)
2. [MediaPipe](#mediapipe)
   - [What is MediaPipe?](#what-is-mediapipe)
   - [How it is configured here](#how-it-is-configured-here)
   - [The 21-Landmark Hand Model](#the-21-landmark-hand-model)
3. [Feature Extraction & Normalisation](#feature-extraction--normalisation)
4. [Gesture Classification Model (KNN)](#gesture-classification-model-knn)
   - [Training pipeline](#training-pipeline)
   - [Prediction pipeline](#prediction-pipeline)
5. [Built-in Cursor Gestures](#built-in-cursor-gestures)
6. [Custom Trainable Gestures & Actions](#custom-trainable-gestures--actions)
7. [System Architecture](#system-architecture)
8. [Key Design Decisions](#key-design-decisions)

---

## Overview

The backend is a standalone Python process (`ml/gesture_service.py`) that:

1. Opens the webcam via OpenCV.
2. Feeds every frame to **MediaPipe Hands** to locate the hand and extract 21 landmarks.
3. Converts those landmarks into a compact 63-dimensional feature vector.
4. Passes the vector to a **K-Nearest Neighbours (KNN) classifier** trained on the user's own gesture samples.
5. Translates the recognised gesture into a desktop action (mouse movement, click, keyboard shortcut, media key, etc.) using **PyAutoGUI / pynput**.
6. Streams live video frames and detection events over a **WebSocket** connection to the Node.js server, which forwards them to the browser.

---

## MediaPipe

### What is MediaPipe?

[MediaPipe](https://google.github.io/mediapipe/) is an open-source, cross-platform framework developed by Google. It provides production-quality ML pipeline components for vision, audio, and sensor data. This project uses the **MediaPipe Hands** solution.

MediaPipe Hands is itself a two-stage pipeline:

| Stage | Model | Purpose |
|-------|-------|---------|
| 1 – Palm Detection | **BlazePalm** (SSD-based single-shot detector) | Finds the bounding box of the palm in the full image. Runs only when no hand is being tracked, making it very efficient. |
| 2 – Hand Landmark | **BlazeLandmark** (regression network) | Localises 21 3D keypoints on the detected hand at high frame rates. |

Both models are lightweight neural networks optimised for mobile and desktop CPU inference, achieving real-time performance without a GPU.

### How it is configured here

```python
# ml/gesture_service.py — HandDetector.__init__
self.hands = mp.solutions.hands.Hands(
    static_image_mode=False,       # Video mode: tracks across frames
    max_num_hands=1,               # Only the first (dominant) hand is used
    min_detection_confidence=0.7,  # BlazePalm must be ≥70% confident
    min_tracking_confidence=0.6,   # BlazeLandmark tracker threshold
)
```

- **`static_image_mode=False`** — enables the tracking path: BlazePalm runs once to detect the hand, then BlazeLandmark tracks it frame-by-frame. BlazePalm only re-runs when tracking is lost, keeping CPU usage low.
- **`max_num_hands=1`** — restricts processing to a single hand to simplify classification and reduce latency.
- **`min_detection_confidence=0.7`** — a palm bounding box below 70% confidence is discarded, reducing false positives in cluttered backgrounds.
- **`min_tracking_confidence=0.6`** — if the tracker confidence drops below 60%, BlazePalm is invoked again to re-detect the hand.

### The 21-Landmark Hand Model

BlazeLandmark returns **21 keypoints**, each with `(x, y, z)` coordinates normalised to the image dimensions:

```
                   8   12  16  20        ← Fingertips
                   |    |   |   |
                   7   11  15  19        ← DIP joints
                   |    |   |   |
                   6   10  14  18        ← PIP joints
                   |    |   |   |
                   5    9  13  17        ← MCP joints
                    \   |   |  /
              4      \  |  /
             (Tip)    \ | /
              3       [Palm]             ← Thumb IP joint
             (IP)       |
              2          |               ← Thumb MCP joint
             (MCP)       |
              1          |               ← Thumb CMC joint
             (CMC)       |
                         0  ← Wrist
```

| ID Range | Landmark group |
|----------|---------------|
| 0 | Wrist |
| 1 – 4 | Thumb (CMC → Tip) |
| 5 – 8 | Index finger (MCP → Tip) |
| 9 – 12 | Middle finger (MCP → Tip) |
| 13 – 16 | Ring finger (MCP → Tip) |
| 17 – 20 | Pinky (MCP → Tip) |

---

## Feature Extraction & Normalisation

Raw landmark coordinates are scale- and position-dependent (the same gesture looks different if the hand is close or far from the camera). To make the feature vector invariant to hand size and position, `HandDetector._normalise()` applies two steps:

```python
# ml/gesture_service.py — HandDetector._normalise
pts = np.array([[lm.x, lm.y, lm.z] for lm in hand.landmark], dtype=np.float32)
pts -= pts[0]          # 1. Translate: move wrist to the origin
max_val = np.max(np.abs(pts))
if max_val > 0:
    pts /= max_val     # 2. Scale: map all values to [-1, 1]
return pts.flatten()   # 3. Flatten: 21 × 3 → 63-element vector
```

**Step 1 — Translation:** subtract the wrist coordinate (landmark 0) from every point, making all coordinates relative to the wrist. This removes position dependency.

**Step 2 — Scaling:** divide every coordinate by the maximum absolute value across the hand. This normalises for hand size and distance from the camera, mapping the entire hand into the unit cube `[-1, 1]³`.

**Result:** a **63-element `float32` vector** that encodes the *shape* of the hand independently of where it is or how big it appears.

---

## Gesture Classification Model (KNN)

### Training pipeline

```
User records ≥80 samples per gesture
        ↓
Each frame → MediaPipe → 63-D vector → saved as .npy file
        ↓
All samples loaded: X (N×63), y (N labels)
        ↓
80/20 stratified train/test split
        ↓
KNeighborsClassifier(n_neighbors=k, weights="distance")  fit on X_train
        ↓
Accuracy evaluated on X_test
        ↓
Model + LabelEncoder saved to models/gesture_model.pkl
```

Key parameters:

| Parameter | Value | Reason |
|-----------|-------|--------|
| `n_neighbors` | `min(5, len(X_train))` | Up to 5 nearest neighbours; fewer when training data is small |
| `weights` | `"distance"` | Closer neighbours vote with more weight, improving boundary sharpness |
| Test split | 20% | Standard holdout; stratified to preserve class balance |
| Samples per gesture | 80 (default) | Balances training time against coverage of pose variation |

### Prediction pipeline

For every incoming frame:

```
63-D vector
    │
    ├─ 1. Outlier check
    │      kneighbors(vector, k=1) → nearest-neighbour distance
    │      if distance > 0.65  →  return (None, 0.0)   # unknown hand pose
    │
    ├─ 2. Probability check
    │      predict_proba(vector) → class probabilities
    │      max_confidence = max(proba)
    │      if max_confidence < 0.55  →  return (None, 0.0)
    │
    └─ 3. Debounce buffer (6 frames)
           require ≥70% of recent frames to agree on the same label
           if threshold met  →  emit gesture event
```

The two-stage confidence gate (outlier distance + probability threshold) prevents spurious detections when the user's hand is in an unrecognised pose or partially out of frame.

The **debounce buffer** ensures that a gesture must be held steadily for several consecutive frames before an action fires, eliminating jitter from single-frame misclassifications.

---

## Built-in Cursor Gestures

These gestures work without any training. They are detected geometrically from the raw landmark positions inside `CursorController`:

| Gesture | Detection logic | Default action |
|---------|----------------|----------------|
| **Thumb + Index pinch** | Euclidean distance between landmarks 4 and 8 < 0.05 | Left click |
| **Thumb + Middle pinch** | Distance between landmarks 4 and 12 < 0.05 | Right click |
| **Closed fist** | All 5 fingertips within 0.15 of the wrist (landmark 0) | Drag start / stop |
| **Two fingers extended** | Exactly 2 fingers with tip above PIP joint | Scroll (vertical movement of middle finger) |
| **Open palm** | All 5 fingertips more than 0.20 from the wrist | Scroll / open palm actions |
| **Point (1 finger)** | Only index finger extended | Enter click-mode; confirm target with pinch |

Cursor **movement** is driven by the index fingertip (landmark 8), mapped linearly to screen coordinates with:
- A **dead zone** (2% of screen width/height) to filter microtremors.
- **Exponential smoothing** (`α = 0.5`) to produce fluid motion.

---

## Custom Trainable Gestures & Actions

Users record their own gestures and map them to any of the following built-in actions:

**Navigation**

| Action key | Effect |
|------------|--------|
| `alt_tab` / `switch_window` | Alt + Tab |
| `next_tab` / `prev_tab` | Ctrl + Tab / Ctrl + Shift + Tab |
| `go_back` / `go_forward` | Alt + ← / Alt + → |
| `close_tab` / `new_tab` | Ctrl + W / Ctrl + T |

**Media**

| Action key | Effect |
|------------|--------|
| `play_pause` | Play / Pause media key |
| `media_next` / `media_prev` | Next / Previous track |
| `volume_up` / `volume_down` | Volume keys |
| `mute` | Mute |

**System**

| Action key | Effect |
|------------|--------|
| `screenshot` | Win + Shift + S |
| `lock_screen` | Win + L |
| `show_desktop` | Win + D |
| `task_view` | Win + Tab |
| `minimize_all` | Win + M |

**Editing & Misc**

`scroll_up`, `scroll_down`, `enter`, `escape`, `undo`, `redo`, `copy`, `paste`

Custom gestures can also be mapped to cursor actions (`left_click`, `right_click`, `drag`) inside Cursor Control mode.

---

## System Architecture

```
Browser (React)
      │  WebSocket (frames + events)
      ▼
Node.js server  (port 3001)
      │  WebSocket bridge
      ▼
Python ML service  (port 8765)
      │
      ├── OpenCV  →  capture frame from webcam
      ├── MediaPipe Hands  →  21 landmarks
      ├── HandDetector._normalise  →  63-D vector
      ├── GestureClassifier.predict  →  label + confidence
      ├── ActionExecutor  →  PyAutoGUI / pynput hotkeys
      └── CursorController  →  mouse move / click / drag / scroll
```

The Python service encodes every annotated frame as a base64 JPEG and sends it back over WebSocket so the browser can render the live hand skeleton overlay without accessing the camera directly.

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **KNN over a neural network** | KNN needs no re-training infrastructure, works well with few samples (80 per class), and is fully interpretable. The 63-D normalised space makes Euclidean distance meaningful. |
| **Distance-based outlier gate** | Prevents the classifier from forcing every hand pose into a known class. Poses far from any training sample return `None` instead of a wrong label. |
| **Debounce + cooldown** | Debounce (6-frame buffer) filters transient misclassifications; cooldown (1.2 s default) prevents action spam when a gesture is held. |
| **MediaPipe for landmark extraction** | Avoids building a hand detector from scratch. BlazePalm + BlazeLandmark are accurate, fast, and run on CPU without a GPU. |
| **Wrist-anchored normalisation** | Makes the feature vector invariant to hand position and scale, which is the main source of intra-class variation in static gesture datasets. |
| **PyAutoGUI FAILSAFE=True** | Moving the mouse to a screen corner stops all automation — a safety mechanism to regain control if gesture detection misbehaves. |
