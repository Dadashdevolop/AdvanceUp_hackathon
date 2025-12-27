from database import SessionLocal
import crud

db = SessionLocal()
readings = crud.get_all_readings(db, limit=1)
print(f'Database kayıt sayısı: {len(readings)}')
if readings:
    r = readings[0]
    print(f'Son kayıt:')
    print(f'  - ID: {r.id}')
    print(f'  - Source: {r.source_id}')
    print(f'  - Temp: {r.temperature}°C')
    print(f'  - Detected: {r.detected_object}')
    print(f'  - Timestamp: {r.timestamp}')
else:
    print('❌ Database BOŞ! Test verisi ekleniyor...')
    
    # Test verisi ekle
    from schemas import ReadingCreate
    test_data = ReadingCreate(
        source_id="Test_Device",
        temperature=22.5,
        humidity=65.0,
        water_level=450,
        distance=15,
        light_level=300,
        sound_level=200,
        motor_status=False,
        is_danger=False,
        detected_object="Sistem Test"
    )
    crud.create_reading(db, test_data)
    print('✅ Test verisi eklendi!')

db.close()
