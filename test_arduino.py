"""
Arduino Test Script - Bağlantıyı ve veri formatını test et
"""
import serial
import time
import sys

def test_arduino(port='COM9', baud_rate=9600):
    """Arduino bağlantısını test et"""
    print(f"🔍 Port: {port} test ediliyor...")
    
    try:
        # Seri port aç
        ser = serial.Serial(port, baud_rate, timeout=1)
        time.sleep(2)  # Arduino reset için bekle
        print(f"✅ {port} portuna bağlandı")
        print("📡 Veri bekleniyor... (Çıkmak için Ctrl+C)\n")
        
        line_count = 0
        while line_count < 20:  # İlk 20 satırı göster
            if ser.in_waiting > 0:
                line = ser.readline()
                try:
                    decoded = line.decode('utf-8').strip()
                    print(f"[{line_count+1}] Raw: {decoded}")
                    
                    # Parse et
                    data = decoded.split(',')
                    if len(data) >= 8:
                        print(f"    ✓ Sıcaklık: {data[0]}°C")
                        print(f"    ✓ Nem: {data[1]}%")
                        print(f"    ✓ Mesafe: {data[2]} cm")
                        print(f"    ✓ Işık: {data[3]}")
                        print(f"    ✓ Hareket: {'VAR' if data[4]=='1' else 'YOK'}")
                        print(f"    ✓ Ses: {data[5]}")
                        print(f"    ✓ Su: {data[6]}")
                        print(f"    ✓ Motor: {'AÇIK' if data[7]=='1' else 'KAPALI'}")
                    else:
                        print(f"    ⚠️ Eksik veri: {len(data)} alan (8 olmalı)")
                    print()
                    line_count += 1
                except Exception as e:
                    print(f"    ❌ Decode hatası: {e}")
            
            time.sleep(0.1)
        
        ser.close()
        print("\n✅ Test tamamlandı!")
        print("\nArduino formatı doğruysa backend'i başlat:")
        print("  python -m uvicorn main:app --reload")
        print("\nSonra Arduino servisini başlat (API call veya Postman):")
        print(f"  POST http://localhost:8000/api/arduino/start?port={port}")
        print("  Header: X-API-Key: AgroShield_Secret_2025")
        
    except serial.SerialException as e:
        print(f"\n❌ Bağlantı hatası: {e}")
        print("\n💡 Çözümler:")
        print("  1. Arduino USB bağlantısını kontrol et")
        print("  2. Doğru COM portunu kullandığından emin ol")
        print("  3. Başka program portu kullanıyor olabilir (Arduino IDE, Serial Monitor)")
        print("  4. Cihaz Yöneticisi'nden (Device Manager) COM portunu kontrol et")
        return False
    except KeyboardInterrupt:
        print("\n⏹️ Test durduruldu")
        ser.close()
    except Exception as e:
        print(f"\n❌ Hata: {e}")
        return False
    
    return True

if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else 'COM9'
    
    print("="*60)
    print("        ARDUINO BAĞLANTI TEST ARACI")
    print("="*60)
    print(f"\nKullanım: python test_arduino.py [PORT]")
    print(f"Örnek: python test_arduino.py COM5\n")
    
    test_arduino(port)
