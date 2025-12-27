import json
import asyncio
import threading
import base64
import cv2
import numpy as np
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, Security, status
from fastapi.responses import StreamingResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from sqlalchemy.orm import Session
from subprocess import Popen
import os
import models
import schemas
import crud
from database import SessionLocal, engine
import audio_model
from arduino_service import ArduinoService

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Agro-Shield API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

latest_data_cache: Optional[str] = None
current_frame: Optional[bytes] = None
frame_lock = threading.Lock()
streaming_active = False  # Mobil kontrolü için flag
controller_process: Optional[Popen] = None  # Track controller process
arduino_service: Optional[ArduinoService] = None  # Arduino sensor service


def _placeholder_jpeg():
    """Return a small black JPEG to avoid 404 when no frame is available."""
    frame = np.zeros((360, 640, 3), dtype=np.uint8)
    _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
    return jpeg.tobytes()

API_KEY = "AgroShield_Secret_2025"
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

async def get_api_key(api_key_header: str = Security(api_key_header)):
    if api_key_header == API_KEY:
        return api_key_header
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid API Key"
        )

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception:
                pass

manager = ConnectionManager()

@app.get("/")
def root():
    return {"status": "Online", "time": datetime.now()}

@app.post("/api/update", response_model=schemas.ReadingResponse, dependencies=[Depends(get_api_key)])
async def update_status(reading: schemas.ReadingCreate, db: Session = Depends(get_db)):
    global latest_data_cache
    db_reading = crud.create_reading(db=db, reading=reading)
    data_dict = reading.dict()
    data_dict["id"] = db_reading.id
    data_dict["timestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    latest_data_cache = json.dumps(data_dict)
    await manager.broadcast(latest_data_cache)
    return db_reading

def handle_arduino_data(data: dict):
    """Arduino'dan gelen veriyi işle (callback)"""
    try:
        # Sync fonksiyonu async'e çevirmeden direkt veritabanına kaydet
        db = SessionLocal()
        reading = schemas.ReadingCreate(**data)
        db_reading = crud.create_reading(db=db, reading=reading)
        
        # WebSocket'e broadcast için veri hazırla
        data_dict = data.copy()
        data_dict["id"] = db_reading.id
        data_dict["timestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        global latest_data_cache
        latest_data_cache = json.dumps(data_dict)
        
        # Tüm WebSocket bağlantılarına veriyi gönder (sync broadcast)
        disconnected = []
        for idx, connection in enumerate(manager.active_connections):
            try:
                # Thread-safe broadcast için sync wrapper
                import asyncio
                loop = None
                try:
                    loop = asyncio.get_running_loop()
                except RuntimeError:
                    pass
                
                if loop:
                    # Eğer event loop varsa (async context'te) task oluştur
                    asyncio.create_task(connection.send_text(latest_data_cache))
                else:
                    # Event loop yoksa direkt gönder (blocking)
                    asyncio.run(connection.send_text(latest_data_cache))
                    
            except Exception as e:
                print(f"[WebSocket] Bağlantı {idx} gönderimi hatası: {e}", flush=True)
                disconnected.append(idx)
        
        # Kesilen bağlantıları kaldır
        for idx in reversed(disconnected):
            if idx < len(manager.active_connections):
                manager.active_connections.pop(idx)
        
        db.close()
        print(f"✅ Arduino verisi kaydedildi: {data['detected_object']} ({len(manager.active_connections)} WebSocket)", flush=True)
    except Exception as e:
        print(f"❌ Arduino veri işleme hatası: {e}", flush=True)

@app.post("/api/frame/update", dependencies=[Depends(get_api_key)])
async def update_frame(frame_data: dict):
    """Edge controller'dan frame bilgisi alır ve stream'e aktarır"""
    global current_frame, streaming_active
    try:
        # Streaming aktif değilse frame'leri al ama log yapma
        frame_base64 = frame_data.get("frame_base64")
        if not frame_base64:
            return {"status": "error", "detail": "frame_base64 missing"}

        decoded = base64.b64decode(frame_base64)
        with frame_lock:
            current_frame = decoded

        return {"status": "ok", "size": len(decoded), "streaming": streaming_active}
    except Exception as e:
        print(f"[Video] Frame update error: {e}", flush=True)
        return {"status": "error", "detail": str(e)}

async def generate_mjpeg():
    """MJPEG frame generator (Motion JPEG stream)"""
    global current_frame
    while True:
        with frame_lock:
            frame_bytes = current_frame if current_frame is not None else _placeholder_jpeg()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n'
                   b'Content-Length: ' + str(len(frame_bytes)).encode() + b'\r\n\r\n'
                   + frame_bytes + b'\r\n')
        await asyncio.sleep(0.005)  # faster pacing

@app.get("/api/video/stream")
async def video_stream():
    """MJPEG live stream endpoint"""
    return StreamingResponse(
        generate_mjpeg(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={"Cache-Control": "no-cache, no-store, must-revalidate"}
    )

@app.get("/api/video/frame")
async def video_frame():
    """Latest single JPEG frame (non-streaming) for polling clients"""
    with frame_lock:
        try:
            frame_bytes = current_frame if current_frame is not None else _placeholder_jpeg()
            return Response(
                content=frame_bytes,
                media_type="image/jpeg",
                headers={"Cache-Control": "no-cache, no-store, must-revalidate"}
            )
        except Exception as e:
            print(f"[Video] Single frame error: {e}", flush=True)
            raise HTTPException(status_code=500, detail="Frame processing error")

@app.post("/api/camera/start")
async def start_camera_streaming():
    """Mobil uygulama live view açtığında çağrılır"""
    global streaming_active
    streaming_active = True
    print("[Camera] Streaming STARTED by mobile app", flush=True)
    return {"status": "streaming_started", "active": True}

@app.post("/api/camera/stop")
async def stop_camera_streaming():
    """Mobil uygulama live view kapattığında çağrılır"""
    global streaming_active
    streaming_active = False
    print("[Camera] Streaming STOPPED by mobile app", flush=True)
    return {"status": "streaming_stopped", "active": False}

@app.websocket("/ws/dashboard")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    
    # Eğer cache'de veri yoksa, son veriyi database'den çek
    if latest_data_cache:
        await websocket.send_text(latest_data_cache)
    else:
        # Database'den son veriyi çek ve gönder
        db = SessionLocal()
        try:
            last_reading = crud.get_all_readings(db, limit=1)
            if last_reading:
                reading = last_reading[0]
                data_dict = {
                    "id": reading.id,
                    "source_id": reading.source_id,
                    "temperature": reading.temperature,
                    "humidity": reading.humidity,
                    "water_level": reading.water_level,
                    "distance": reading.distance,
                    "light_level": reading.light_level,
                    "sound_level": reading.sound_level,
                    "motor_status": reading.motor_status,
                    "is_danger": reading.is_danger,
                    "detected_object": reading.detected_object,
                    "image_base64": reading.image_base64,
                    "timestamp": reading.timestamp.strftime("%Y-%m-%d %H:%M:%S") if reading.timestamp else ""
                }
                await websocket.send_text(json.dumps(data_dict))
                print("[WebSocket] İlk veri database'den gönderildi", flush=True)
        except Exception as e:
            print(f"[WebSocket] İlk veri hatası: {e}", flush=True)
        finally:
            db.close()
    
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception:
        manager.disconnect(websocket)

@app.get("/api/history", response_model=List[schemas.ReadingResponse])
def get_history(limit: int = 50, db: Session = Depends(get_db)):
    return crud.get_all_readings(db, limit=limit)

@app.post("/api/audio/analyze", response_model=schemas.AudioAnalyzeResponse, dependencies=[Depends(get_api_key)])
def analyze_audio(payload: schemas.AudioAnalyzeRequest):
    try:
        label, confidence = audio_model.analyze(payload.audio_base64)
        ts = audio_model.now_timestamp()
        return schemas.AudioAnalyzeResponse(label=label, confidence=confidence, timestamp=ts)
    except Exception as e:
        print(f"[API] Audio analyze error: {e}", flush=True)
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=f"Audio analyze error: {str(e)}")

@app.post("/api/controller/start")
def start_controller(x_api_key: Optional[str] = Security(api_key_header)):
    """Start the edge controller (Python process)."""
    global controller_process
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    # Check if already running
    if controller_process is not None:
        try:
            if controller_process.poll() is None:  # Still running
                return {
                    "status": "Controller zaten çalışıyor",
                    "pid": controller_process.pid,
                    "message": "Controller already running"
                }
        except Exception:
            pass
    
    try:
        # Resolve controller path relative to main.py
        backend_dir = os.path.dirname(os.path.abspath(__file__))
        controller_path = os.path.join(backend_dir, "edge", "controller.py")
        python_exe = r"D:\Yazilim\hackathon_backend\venv\Scripts\python.exe"
        
        if not os.path.exists(controller_path):
            raise FileNotFoundError(f"Controller not found: {controller_path}")
        
        # Start controller process (detached, non-blocking)
        controller_process = Popen([python_exe, controller_path])
        
        return {
            "status": "Controller başlatıldı",
            "pid": controller_process.pid,
            "message": f"Controller process started with PID {controller_process.pid}"
        }
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f"[API] Controller start error: {e}", flush=True)
        raise HTTPException(status_code=500, detail=f"Failed to start controller: {str(e)}")

@app.post("/api/controller/stop")
def stop_controller(x_api_key: Optional[str] = Security(api_key_header)):
    """Stop the edge controller process."""
    global controller_process
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    if controller_process is None:
        raise HTTPException(status_code=404, detail="Controller çalışmıyor")
    
    try:
        # Check if process is still running
        if controller_process.poll() is None:
            controller_process.terminate()
            controller_process.wait(timeout=5)
            pid = controller_process.pid
            controller_process = None
            return {
                "status": "Controller durduruldu",
                "pid": pid,
                "message": f"Controller process {pid} terminated"
            }
        else:
            controller_process = None
            raise HTTPException(status_code=404, detail="Controller zaten durmuş")
    except Exception as e:
        print(f"[API] Controller stop error: {e}", flush=True)
        controller_process = None
        raise HTTPException(status_code=500, detail=f"Failed to stop controller: {str(e)}")

# Arduino Sensor Endpoints
@app.post("/api/arduino/start")
def start_arduino_sensor(port: str = "COM9", x_api_key: Optional[str] = Security(api_key_header)):
    """Arduino sensör okumayı başlat"""
    global arduino_service
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    if arduino_service and arduino_service.is_running():
        return {
            "status": "Arduino servisi zaten çalışıyor",
            "port": arduino_service.port,
            "message": "Arduino service already running"
        }
    
    try:
        arduino_service = ArduinoService(port=port)
        arduino_service.set_data_callback(handle_arduino_data)
        
        if arduino_service.start():
            return {
                "status": "Arduino servisi başlatıldı",
                "port": port,
                "message": f"Arduino service started on {port}"
            }
        else:
            raise HTTPException(status_code=500, detail="Arduino bağlantısı kurulamadı")
    except Exception as e:
        print(f"[API] Arduino start error: {e}", flush=True)
        raise HTTPException(status_code=500, detail=f"Failed to start Arduino: {str(e)}")

@app.post("/api/arduino/stop")
def stop_arduino_sensor(x_api_key: Optional[str] = Security(api_key_header)):
    """Arduino sensör okumayı durdur"""
    global arduino_service
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    if arduino_service is None or not arduino_service.is_running():
        raise HTTPException(status_code=404, detail="Arduino servisi çalışmıyor")
    
    try:
        port = arduino_service.port
        arduino_service.stop()
        arduino_service = None
        return {
            "status": "Arduino servisi durduruldu",
            "port": port,
            "message": f"Arduino service stopped"
        }
    except Exception as e:
        print(f"[API] Arduino stop error: {e}", flush=True)
        arduino_service = None
        raise HTTPException(status_code=500, detail=f"Failed to stop Arduino: {str(e)}")

@app.get("/api/arduino/status")
def get_arduino_status():
    """Arduino servis durumunu kontrol et"""
    global arduino_service
    if arduino_service and arduino_service.is_running():
        return {
            "running": True,
            "port": arduino_service.port,
            "message": "Arduino servisi aktif"
        }
    else:
        return {
            "running": False,
            "port": None,
            "message": "Arduino servisi durmuş"
        }