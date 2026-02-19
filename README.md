# GestureCtrl

Control your desktop with hand gestures. No hardware required - just your webcam.

## Features

- **Custom Gestures**: Train your own hand gestures for any action
- **Cursor Control**: Move mouse, click, drag, and scroll with hand movements
- **Real-time Detection**: Fast gesture recognition using MediaPipe
- **System Actions**: Control media playback, switch windows, take screenshots
- **Live Training**: Interactive training with visual feedback
- **Cross-platform**: Works on Windows, macOS, and Linux

## Prerequisites

- Node.js 16+
- Python 3.8+
- Webcam

## Installation

```bash
# Install server dependencies
npm install

# Install frontend dependencies
cd client && npm install && cd ..

# Install Python ML dependencies
pip install -r ml/requirements.txt
```

## Running the App

The project has three separate services. Open three terminal windows and start each one:

```bash
# Terminal 1 — ML service (port 8765)
python ml/gesture_service.py

# Terminal 2 — API server (port 3001)
npm start

# Terminal 3 — Frontend dev server (port 5173)
cd client && npm run dev
```

Then open http://localhost:5173 in your browser.

> The API server and frontend will work without the ML service running, but gesture detection and training won't be available until it's connected.

## Usage

### Training Gestures

1. Go to the **Gestures** tab
2. Click **Add Gesture**, choose a name, icon, and action
3. Click **Record** and perform your gesture — the default session captures 80 samples
4. Repeat recording a few times to cover different hand positions and angles
5. Click **Retrain Model** when done adding gestures

### Cursor Control

1. Go to the **Cursor Control** tab
2. Train gestures for mouse actions (left click, right click, drag, scroll)
3. Enable **Cursor Mode** from the floating widget
4. Control your mouse with hand gestures

## Project Structure

```
├── client/          # React frontend (Vite)
├── server/          # Node.js API server + WebSocket bridge
│   └── index.js
├── ml/              # Python ML service (MediaPipe + KNN)
│   ├── gesture_service.py
│   └── requirements.txt
├── data/            # Gesture definitions and training samples
│   ├── gestures.json
│   └── gestures/    # Per-gesture sample files
├── models/          # Trained model files
└── package.json     # Root package (server scripts)
```

## Tech Stack

- **Frontend**: React, Vite
- **Backend**: Node.js, Express, WebSocket
- **ML**: Python, MediaPipe, scikit-learn
- **Automation**: PyAutoGUI, pynput

## Configuration

Gesture actions can be edited from the UI or by modifying `data/gestures.json` directly.

Available actions:
- Media control (play/pause, next/prev track, volume up/down)
- Window management (alt+tab, close tab, show desktop)
- System shortcuts (screenshot, lock screen)
- Custom keyboard shortcuts
- Cursor actions (left click, right click, drag, scroll)

Service ports are fixed in the code:
- ML service: `8765` (`ml/gesture_service.py`)
- API server: `3001` (`server/index.js`)
- Frontend dev server: `5173` (Vite default)

## Troubleshooting

**Camera not working?**
- Check that your browser has camera permission for `localhost`
- Ensure no other app is using the webcam

**ML service won't connect?**
- Make sure `python ml/gesture_service.py` is running before or shortly after the API server starts — the server retries the connection every 3 seconds automatically

**Gestures not detected?**
- Click **Retrain Model** after adding or updating gestures
- Ensure good, even lighting on your hand
- Keep your hand clearly in frame

**Model accuracy low?**
- Record multiple sessions per gesture from different positions and angles
- Aim for at least 2–3 recording sessions (80 samples each) per gesture

## Contributing

Pull requests welcome. Please open an issue first to discuss significant changes.

Repository: https://github.com/GovindUpadhyay13/Gesture-control

## License

MIT

---

Built with ❤️ for hands-free computing
