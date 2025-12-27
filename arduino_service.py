"""
Arduino Sensor Service - Backend içinde thread olarak çalışır
"""
import serial
import time
import threading
import logging
from typing import Optional, Callable

logger = logging.getLogger(__name__)


class ArduinoService:
    def __init__(self, port: str = 'COM9', baud_rate: int = 9600):
        self.port = port
        self.baud_rate = baud_rate
        self.ser: Optional[serial.Serial] = None
        self.running = False
        self.thread: Optional[threading.Thread] = None
        self.callback: Optional[Callable] = None
        
    def set_data_callback(self, callback: Callable):
        """Veri geldiğinde çağrılacak fonksiyonu ayarla"""
        self.callback = callback
        
    def connect(self) -> bool:
        """Arduino'ya bağlan"""
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                self.ser = serial.Serial(self.port, self.baud_rate, timeout=1)
                time.sleep(2)
                logger.info(f"✅ Arduino bağlandı - Port: {self.port}")
                return True
            except serial.SerialException as e:
                retry_count += 1
                logger.error(f"❌ Arduino bağlantı hatası (Deneme {retry_count}/{max_retries}): {e}")
                if retry_count < max_retries:
                    time.sleep(2)
        
        logger.critical("Arduino bağlantısı kurulamadı")
        return False
    
    def parse_data(self, line: bytes) -> Optional[dict]:
        """Arduino verisini parse et (CLI main.py formatına uygun)"""
        try:
            data = line.decode('utf-8').strip().split(',')
            
            if len(data) < 8:
                logger.warning(f"⚠️ Eksik veri paketi: {len(data)} alan")
                return None

            # CLI formatı: temp, hum, fill_percent, light_val, motion, sound, water_val, motor_state
            temp = float(data[0])
            hum = float(data[1])
            fill_percent = int(data[2])  # Yem doluluk yüzdesi
            light = int(data[3])
            motion = int(data[4])
            sound = int(data[5])
            water = int(data[6])
            motor_state = int(data[7])

            # Tehlike durumu belirleme (CLI main.py eşikleri)
            is_danger = motion == 1 or sound > 600 or water < 300
            
            # Tespit edilen durum
            detected_objects = []
            if motion == 1:
                detected_objects.append("Hareket")
            if sound > 600:
                detected_objects.append("Yüksek Ses")
            if fill_percent < 20:
                detected_objects.append("Yem Azaldı")
            if water < 300:
                detected_objects.append("Su Kritik")
            if light > 600:
                detected_objects.append("Gece Modu")
            
            detected_str = ", ".join(detected_objects) if detected_objects else "Normal"
            
            return {
                "source_id": f"Arduino_Sensor_{self.port}",
                "temperature": round(temp, 1),
                "humidity": round(hum, 1),
                "water_level": water,
                "feed_level": fill_percent,  # Yem doluluk yüzdesi
                "distance": None,  # Artık kullanılmıyor
                "light_level": light,
                "sound_level": sound,
                "motor_status": motor_state == 1,
                "is_danger": is_danger,
                "detected_object": detected_str
            }
            
        except ValueError as e:
            logger.error(f"❌ Veri parsing hatası: {e} | Raw: {line}")
            return None
        except Exception as e:
            logger.error(f"❌ İşleme hatası: {e}")
            return None
    
    def read_loop(self):
        """Sürekli Arduino verisini oku (thread içinde çalışır)"""
        logger.info("🚀 Arduino okuma başladı...")
        
        while self.running and self.ser and self.ser.is_open:
            try:
                if self.ser.in_waiting > 0:
                    line = self.ser.readline()
                    logger.debug(f"📡 Raw Arduino veri: {line}")
                    parsed_data = self.parse_data(line)
                    
                    if parsed_data and self.callback:
                        # Callback fonksiyonunu çağır (backend'e veriyi gönder)
                        logger.info(f"✅ Callback çağrılıyor: {parsed_data['detected_object']}")
                        self.callback(parsed_data)
                    else:
                        if not parsed_data:
                            logger.warning("⚠️ Veri parse edilemedi")
                        if not self.callback:
                            logger.warning("⚠️ Callback ayarlanmamış!")
                
                time.sleep(0.1)  # CPU kullanımını azalt
                
            except serial.SerialException as e:
                logger.error(f"❌ Seri port okuma hatası: {e}")
                break
            except Exception as e:
                logger.error(f"❌ Okuma hatası: {e}")
    
    def start(self) -> bool:
        """Arduino okumayı başlat (thread olarak)"""
        if self.running:
            logger.warning("Arduino servisi zaten çalışıyor")
            return False
        
        if not self.connect():
            return False
        
        self.running = True
        self.thread = threading.Thread(target=self.read_loop, daemon=True)
        self.thread.start()
        logger.info("✅ Arduino servisi başlatıldı")
        return True
    
    def stop(self):
        """Arduino okumayı durdur"""
        if not self.running:
            return
        
        logger.info("⏹️ Arduino servisi durduruluyor...")
        self.running = False
        
        if self.thread:
            self.thread.join(timeout=2)
        
        if self.ser and self.ser.is_open:
            self.ser.close()
            logger.info("🔌 Seri port kapatıldı")
        
        logger.info("Arduino servisi durduruldu")
    
    def is_running(self) -> bool:
        """Servis çalışıyor mu?"""
        return self.running and self.thread and self.thread.is_alive()
