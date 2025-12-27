# Dosya: backend/crud.py
from sqlalchemy.orm import Session
import models, schemas

# YENİ VERİ KAYDETME
def create_reading(db: Session, reading: schemas.ReadingCreate):
    # Pydantic modelini SQLAlchemy modeline çeviriyoruz
    db_reading = models.SensorReading(**reading.dict())
    
    db.add(db_reading)  # Ekle
    db.commit()         # Onayla (Enter'a bas)
    db.refresh(db_reading) # ID atanmış halini geri al
    return db_reading

# EN SON DURUMU GETİR (KÜMES BAZLI)
def get_latest_reading(db: Session, source_id: str):
    # 'source_id'si eşleşenleri bul, tarihe göre tersten sırala, ilkini al
    return db.query(models.SensorReading)\
             .filter(models.SensorReading.source_id == source_id)\
             .order_by(models.SensorReading.timestamp.desc())\
             .first()

# TÜM GEÇMİŞİ GETİR (LOGLAR İÇİN)
def get_all_readings(db: Session, limit: int = 100):
    return db.query(models.SensorReading)\
             .order_by(models.SensorReading.timestamp.desc())\
             .limit(limit)\
             .all()

# BENZERSİZ CİHAZ LİSTESİNİ GETİR (DASHBOARD İÇİN)
def get_active_devices(db: Session):
    # Bu biraz SQL büyüsü: Her cihazın EN SON verisini çekmek için
    # Basitlik adına: Tüm verileri çekip Python'da filtreleyelim (Hackathon hilesi)
    all_data = db.query(models.SensorReading).all()
    device_map = {}
    for data in all_data:
        # Her cihazın en son verisi dictionary'de kalır
        device_map[data.source_id] = data 
    return list(device_map.values())

def check_critical_conditions(db: Session, current_reading):
    # Son 5 veriyi çek
    last_5 = db.query(models.SensorReading).order_by(models.SensorReading.timestamp.desc()).limit(5).all()
    
    # Hepsi yüksek sıcaklık mı?
    high_temp_count = sum(1 for r in last_5 if r.temperature > 40)
    
    if high_temp_count >= 5:
        print("ALARM: Olası Yangın! (Backend Analizi)")
        # Burada Firebase Notification servisini tetikleyebilirsin (Vaktin kalırsa)