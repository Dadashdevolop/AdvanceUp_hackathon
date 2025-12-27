"""
Agro-Shield Edge Controller (YOLO11)
- 720p @60fps capture (low buffer)
- Async frame sender (960x540 JPEG quality 50)
- Detection every 3s on resized input (imgsz=640)
"""

import base64
import datetime
import queue
import random
import threading
import time
from pathlib import Path
import contextlib

import cv2
import requests
from ultralytics import YOLO

try:
    import torch
    torch.set_grad_enabled(False)
except Exception:
    torch = None

# ================= CONFIG =================
SERVER_URL = "https://uninduced-unequilateral-toshia.ngrok-free.dev/api/update"
API_KEY = "AgroShield_Secret_2025"

CAMERA_ID = 0
CAPTURE_WIDTH = 1280
CAPTURE_HEIGHT = 720
REQUEST_FPS = 60
# Use MJPG for faster USB cam decode on Windows
FOURCC = cv2.VideoWriter_fourcc(*"MJPG")

STREAM_WIDTH = 480
STREAM_HEIGHT = 270
FRAME_INTERVAL = 0.2    # 5fps stream - ngrok rate limit için azaltıldı
FRAME_JPEG_QUALITY = 30

SEND_INTERVAL = 0.5     # detection every 500ms for real-time response
DETECT_IMG_SIZE = 384   # tiny input for speed (<50ms inference on GPU)
SHOW_PREVIEW = False
SEND_IMAGE = True
DRAW_OVERLAY = False

# ==========================================

session = requests.Session()
frame_queue: "queue.Queue" = queue.Queue(maxsize=4)


def choose_device():
    """Select CUDA if available; prefer half precision on GPU."""
    if torch is not None and torch.cuda.is_available():
        try:
            torch.backends.cudnn.benchmark = True
        except Exception:
            pass
        return 0, True
    return "cpu", False


def load_model():
    """Load YOLO11 only; resolve path relative to this file."""
    base = Path(__file__).resolve().parent
    ckpt = base / "yolo11n.pt"
    print(f"YOLO modeli yükleniyor: {ckpt.name} ...")
    try:
        return YOLO(str(ckpt))
    except Exception as e:
        raise RuntimeError("yolo11n.pt bulunamadı veya yüklenemedi. edge klasörüne ekleyin.") from e


def get_arduino_data():
    return {
        "temp": round(random.uniform(20.0, 35.0), 1),
        "hum": round(random.uniform(40.0, 60.0), 1),
        "water": random.randint(20, 100),
    }


def open_camera():
    """Try multiple backends on Windows for reliability."""
    candidates = [
        (CAMERA_ID, cv2.CAP_DSHOW),
        (CAMERA_ID, cv2.CAP_MSMF),
        (CAMERA_ID, cv2.CAP_ANY),
        (1, cv2.CAP_DSHOW),
        (1, cv2.CAP_MSMF),
        (1, cv2.CAP_ANY),
    ]
    for cam_id, backend in candidates:
        try:
            cap = cv2.VideoCapture(cam_id, backend)
            time.sleep(0.2)
            if cap.isOpened():
                print(f"🎥 Kamera açıldı: id={cam_id}, backend={backend}")
                return cap
            cap.release()
        except Exception as e:
            print(f"[Kamera] Açma hatası (id={cam_id}, backend={backend}): {e}")
    return None


def frame_sender(server_url: str, api_key: str):
    """Background sender: downscale, encode, post latest frames quickly."""
    headers = {"Content-Type": "application/json", "X-API-Key": api_key}
    frame_url = server_url.replace("/api/update", "/api/frame/update")
    while True:
        frame = frame_queue.get()
        if frame is None:
            break
        try:
            try:
                resized = cv2.resize(frame, (STREAM_WIDTH, STREAM_HEIGHT))
            except Exception:
                resized = frame
            ok, buffer = cv2.imencode(
                ".jpg", resized, [int(cv2.IMWRITE_JPEG_QUALITY), FRAME_JPEG_QUALITY]
            )
            if not ok:
                continue
            jpg = base64.b64encode(buffer).decode("utf-8")
            payload = {"frame_base64": jpg, "timestamp": datetime.datetime.now().isoformat()}
            session.post(frame_url, json=payload, headers=headers, timeout=0.5)
        except Exception as e:
            print(f"[Frame] Gönderim hatası: {e}")


def main():
    cv2.setUseOptimized(True)
    try:
        cv2.setNumThreads(0)
    except Exception:
        pass

    model = load_model()
    device, use_half = choose_device()

    # Warmup: eliminate first-inference delay
    print("🔥 Model warmup...")
    import numpy as np
    dummy = np.zeros((DETECT_IMG_SIZE, DETECT_IMG_SIZE, 3), dtype=np.uint8)
    try:
        with torch.inference_mode() if torch is not None else contextlib.nullcontext():
            _ = model.predict(dummy, device=device, imgsz=DETECT_IMG_SIZE, half=use_half, verbose=False)
    except Exception:
        pass
    print("✅ Model hazır")

    cap = open_camera()
    if cap is None:
        print("Kamera açılamadı! Alternatif id/backend denemeleri başarısız.")
        return

    try:
        cap.set(cv2.CAP_PROP_FOURCC, FOURCC)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAPTURE_WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAPTURE_HEIGHT)
        cap.set(cv2.CAP_PROP_FPS, REQUEST_FPS)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        print(
            f"🎛️ Kamera ayarlandı: {CAPTURE_WIDTH}x{CAPTURE_HEIGHT} @{REQUEST_FPS}fps, buffer=1, fourcc=MJPG"
        )
    except Exception as e:
        print(f"[Kamera] Ayar hatası: {e}")

    print("-" * 50)
    print(f"📡 Sunucu: {SERVER_URL}")
    print(f"🔑 API Key: {API_KEY}")
    print("-" * 50)

    last_payload_time = 0.0
    last_frame_time = 0.0

    sender = threading.Thread(target=frame_sender, args=(SERVER_URL, API_KEY), daemon=True)
    sender.start()

    detected_obj = "Guvenli"
    is_danger = False

    while True:
        ret, frame = cap.read()
        if not ret or frame is None:
            print("[Kamera] Kare okunamadı, yeniden denenecek...")
            time.sleep(0.02)
            continue

        now = time.time()

        # Detection + sensor payload every SEND_INTERVAL seconds
        if now - last_payload_time >= SEND_INTERVAL:
            try:
                det_frame = cv2.resize(frame, (DETECT_IMG_SIZE, int(DETECT_IMG_SIZE * 9 / 16)))
            except Exception:
                det_frame = frame

            try:
                with torch.inference_mode() if torch is not None else contextlib.nullcontext():
                    results = model.predict(
                        det_frame, device=device, imgsz=DETECT_IMG_SIZE, half=use_half, verbose=False
                    )
            except Exception as e:
                print(f"[YOLO] Predict hatası: {e}")
                results = []

            detected_obj = "Guvenli"
            is_danger = False
            best_conf = -1.0

            threat_classes = {"person", "dog", "bear", "cat", "wolf"}
            label_map = {
                "person": "Person",
                "dog": "Dog",
                "bear": "Bear",
                "cat": "Cat",
                "wolf": "Wolf",
                "cow": "Cow",
                "cell phone": "Phone",
                "laptop": "Laptop",
            }

            h0, w0 = det_frame.shape[:2]
            h1, w1 = frame.shape[:2]
            sx, sy = w1 / w0, h1 / h0

            if DRAW_OVERLAY:
                overlay = frame.copy()
                try:
                    for result in results:
                        boxes = getattr(result, "boxes", [])
                        for box in boxes:
                            cls_id = int(box.cls[0])
                            name = getattr(model, "names", {}).get(cls_id, str(cls_id))
                            conf = float(box.conf[0]) if getattr(box, "conf", None) is not None else 0.0
                            label = label_map.get(name, name)

                            x1, y1, x2, y2 = map(int, box.xyxy[0])
                            X1, Y1, X2, Y2 = int(x1 * sx), int(y1 * sy), int(x2 * sx), int(y2 * sy)

                            color = (0, 255, 0)
                            if name in threat_classes:
                                is_danger = True
                                color = (0, 0, 255)

                            if conf > best_conf:
                                best_conf = conf
                                detected_obj = label

                            cv2.rectangle(overlay, (X1, Y1), (X2, Y2), color, 2)
                            cv2.putText(overlay, label, (X1, Y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
                except Exception:
                    pass
            else:
                # Still extract class names without drawing
                try:
                    for result in results:
                        boxes = getattr(result, "boxes", [])
                        for box in boxes:
                            cls_id = int(box.cls[0])
                            name = getattr(model, "names", {}).get(cls_id, str(cls_id))
                            conf = float(box.conf[0]) if getattr(box, "conf", None) is not None else 0.0
                            label = label_map.get(name, name)
                            if name in threat_classes:
                                is_danger = True
                            if conf > best_conf:
                                best_conf = conf
                                detected_obj = label
                except Exception:
                    pass

            sensor = get_arduino_data()
            payload = {
                "source_id": "Kumes_Ana_Bolge",
                "temperature": sensor["temp"],
                "humidity": sensor["hum"],
                "water_level": sensor["water"],
                "is_danger": is_danger,
                "detected_object": detected_obj,
            }
            
            if SEND_IMAGE:
                target_frame = overlay if DRAW_OVERLAY else frame
                ok, buf = cv2.imencode(".jpg", target_frame, [int(cv2.IMWRITE_JPEG_QUALITY), 50])
                if ok:
                    payload["image_base64"] = base64.b64encode(buf).decode("utf-8")
            try:
                headers = {"Content-Type": "application/json", "X-API-Key": API_KEY}
                resp = session.post(SERVER_URL, json=payload, headers=headers, timeout=2)
                if resp.status_code == 200:
                    print(f"✅ [{datetime.datetime.now().strftime('%H:%M:%S')}] Veri gönderildi -> {detected_obj}")
                else:
                    print(f"❌ [{resp.status_code}] Sunucu Hatası: {resp.text}")
            except Exception as e:
                print(f"⚠️ Bağlantı Hatası: {e}")
            last_payload_time = now

        # Enqueue latest frame for background sending
        if now - last_frame_time >= FRAME_INTERVAL:
            try:
                if not frame_queue.full():
                    frame_queue.put(frame.copy())
                else:
                    try:
                        _ = frame_queue.get_nowait()
                    except Exception:
                        pass
                    frame_queue.put(frame.copy())
            except Exception as e:
                print(f"[Frame] Kuyruk hatası: {e}")
            last_frame_time = now

        if SHOW_PREVIEW:
            cv2.imshow("Agro-Shield AI Camera", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    cap.release()
    cv2.destroyAllWindows()
    try:
        frame_queue.put(None)
    except Exception:
        pass


if __name__ == "__main__":
    main()
