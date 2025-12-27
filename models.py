# Dosya: backend/models.py
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from database import Base
from datetime import datetime

class SensorReading(Base):
    __tablename__ = "readings" # Tablomuzun adı

    id = Column(Integer, primary_key=True, index=True) # Her veri için eşsiz numara (1, 2, 3...)
    source_id = Column(String, index=True)             # Örn: "Kumes_1", "Depo"
    
    temperature = Column(Float)     # Sıcaklık
    humidity = Column(Float)        # Nem
    water_level = Column(Integer)   # Su Seviyesi %
    feed_level = Column(Integer, nullable=True)  # Yem doluluk yüzdesi (%)
    distance = Column(Integer, nullable=True)  # Yem stoğu mesafesi (cm) - eski alan
    light_level = Column(Integer, nullable=True)  # Işık seviyesi (0-1023)
    sound_level = Column(Integer, nullable=True)  # Ses seviyesi (0-1023)
    motor_status = Column(Boolean, nullable=True)  # Motor durumu (True: Açık)
    
    is_danger = Column(Boolean, default=False) # Tehlike var mı?
    detected_object = Column(String)           # "Kurt", "İnsan"
    
    image_base64 = Column(String, nullable=True) # Fotoğraf (Metin olarak saklanır)
    
    timestamp = Column(DateTime, default=datetime.now) # Kayıt zamanı