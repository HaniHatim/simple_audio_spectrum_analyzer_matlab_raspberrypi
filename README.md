# Real-Time Audio Spectrum Analyzer (MATLAB & Raspberry Pi 5)

![MATLAB](https://img.shields.io/badge/Made_with-MATLAB-orange)
![Raspberry Pi](https://img.shields.io/badge/Hardware-Raspberry%20Pi%205-red)
![Status](https://img.shields.io/badge/Status-Working-brightgreen)

## 📌 Project Overview

This project is a Digital Signal Processing (DSP) system that visualizes audio frequencies in real-time. We designed it as a distributed system:
1. **PC (MATLAB):** Handles the signal acquisition and FFT processing.
2. **Raspberry Pi 5:** Hosts a low-latency web server to visualize the data on any device on the network.

### Project Demo
<div align="center">
  <img src="https://github.com/HaniHatim/simple_audio_spectrum_analyzer_matlab_raspberrypi/blob/main/Images/ExampDispPIASA.jpeg" width="700" alt="Live Spectrum Analyzer Display">
</div>

### Why Raspberry Pi 5?
We specifically implemented this on the **Raspberry Pi 5** running Raspberry Pi OS (Bookworm).  
The increased processing power ensures the Flask server and WebSockets run smoothly, even when receiving high-speed UDP packets from MATLAB.

---

## 📦 Requirements

### 🔹 **MATLAB Requirements**
You **must install the following add-ons** from MATLAB Add-On Explorer:

| Requirement | Purpose |
|------------|---------|
| **Audio Toolbox** | For real-time audio capture (`audiodeviceReader`) |
| **DSP System Toolbox** | For FFT, windowing, and spectral operations |
| **Instrument Control Toolbox** *(optional)* | Only needed if you want to debug or extend UDP networking |
| **MATLAB Support for WebSockets** *(optional)* | Not required for this project, but useful for expansion |

> ⚠️ **Without Audio Toolbox, the microphone input will NOT work.**

---

### 🔹 **Windows Audio Setup (Stereo Mix)**
If you want to visualize **system audio** (YouTube, Spotify, games, etc.), enable **Stereo Mix** on Windows:

1. Right-click the 🔊 **audio icon** → *Sound Settings*  
2. Scroll down → **More sound settings**  
3. Open the **Recording** tab  
4. Right-click inside the list → check **Show Disabled Devices**  
5. Enable **Stereo Mix**  
6. Right-click → **Set as Default Device** (or select it inside MATLAB)

If Stereo Mix does not appear, install your motherboard’s official **Realtek Audio drivers**.

---

## 🔧 How It Works (The Code Logic)

### 1. The Source (MATLAB)
The MATLAB script (`AudioAnalyzer.m`):
- Captures audio from the microphone or Stereo Mix
- Applies a **Hann Window**
- Computes a **Fast Fourier Transform (FFT)**
- Reduces data to **64 frequency bins**
- Sends JSON packets via **UDP** to the Raspberry Pi

### 2. The Server (Raspberry Pi 5)
A Python Flask + Socket.IO server:
- Listens on **UDP port 5005**
- Receives FFT packets
- Pushes data to the browser using WebSockets
- Uses **eventlet** for ultra-low latency

### 3. The Visualization (HTML/JS)
A simple webpage using **Chart.js** displays 64 real-time frequency bars at ~30 FPS.

---

## 🚀 Installation & Setup

### 1. Raspberry Pi 5 Setup (Important)

Bookworm OS enforces PEP 668, so you cannot install Python packages globally unless you use a virtual environment.

#### Option A: Create a virtual environment (Recommended)
```bash
python3 -m venv venv
source venv/bin/activate
pip install flask flask-socketio eventlet
