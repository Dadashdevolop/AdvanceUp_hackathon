# Dosya: backend/schemas.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

# 1. Veri Oluştururken İstediğimiz Format (AI Bilgisayarından gelen)
class ReadingCreate(BaseModel):
    source_id: str
    temperature: float
    humidity: float
    water_level: int
    feed_level: Optional[int] = None  # Yem doluluk yüzdesi (%0-100)
    distance: Optional[int] = None  # Yem stoğu mesafesi (cm) - eski alan
    light_level: Optional[int] = None  # LDR sensörü (0-1023)
    sound_level: Optional[int] = None  # Ses seviyesi (0-1023)
    motor_status: Optional[bool] = None  # Motor durumu (True: Açık)
    is_danger: bool
    detected_object: str
    image_base64: Optional[str] = None

# 2. Veri Okurken Göstereceğimiz Format (Mobil Uygulamaya giden)
class ReadingResponse(ReadingCreate):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True # ORM nesnesini Pydantic'e çevirmek için şart

# 3. Ses Analizi İstek/Yanıt Şemaları
class AudioAnalyzeRequest(BaseModel):
    audio_base64: str
    sample_rate: Optional[int] = None

class AudioAnalyzeResponse(BaseModel):
    label: str
    confidence: float
    timestamp: datetime