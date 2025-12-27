import serial
import time
import os
import datetime

# --- SISTEM YAPILANDIRMASI ---
ARDUINO_PORT = 'COM9'  # Portunuzu buraya girin
BAUD_RATE = 9600
TIMEOUT = 1

def clear_screen():
    """Isletim sistemine gore ekrani temizler."""
    os.system('cls' if os.name == 'nt' else 'clear')

def draw_progress_bar(percentage, length=20):
    """ASCII karakterleri ile doluluk cubugu olusturur."""
    fill_count = int(length * percentage / 100)
    empty_count = length - fill_count
    # Endüstriyel görünüm için kare (#) veya çizgi (|) kullanılır
    bar = '#' * fill_count + '-' * empty_count
    return f"[{bar}]"

def main():
    # Seri Port Baglantisi Kurulumu
    try:
        ser = serial.Serial(ARDUINO_PORT, BAUD_RATE, timeout=TIMEOUT)
        time.sleep(2) # Baglantinin oturmasi icin bekleme
    except serial.SerialException:
        print(f"[HATA] {ARDUINO_PORT} portuna baglanilamadi. Lutfen kabloyu ve portu kontrol edin.")
        return

    print("Sistem baslatiliyor... Veri akisi bekleniyor.")

    while True:
        try:
            if ser.in_waiting > 0:
                line = ser.readline()
                try:
                    # Gelen veriyi UTF-8 formatinda coz ve parcala
                    data_str = line.decode('utf-8').strip()
                    data = data_str.split(',')

                    # Veri butunlugu kontrolu (8 parametre bekleniyor)
                    if len(data) < 8:
                        continue

                    # Verileri degiskenlere ata ve tiplerini donustur
                    temp = float(data[0])        # Sicaklik
                    hum = float(data[1])         # Nem
                    fill_percent = int(data[2])  # Yem Doluluk (%)
                    light_val = int(data[3])     # Isik Degeri
                    motion = int(data[4])        # Hareket (0/1)
                    sound = int(data[5])         # Ses Degeri
                    water_val = int(data[6])     # Su Degeri
                    motor_state = int(data[7])   # Motor Durumu (0/1)

                    # --- DURUM ANALIZI ---
                    current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    
                    # Isik Durumu (LDR > 600 ise Gece Modu)
                    light_status = "GECE (LEDLER AKTIF)" if light_val > 600 else "GUNDUZ"
                    
                    # Su Durumu
                    water_status = "NORMAL" if water_val > 300 else "KRITIK - DOLUM YAPILIYOR"
                    
                    # Motor Durumu
                    motor_status_str = "CALISIYOR" if motor_state == 1 else "DURDURULDU"

                    # --- DASHBOARD GORUNUMU ---
                    clear_screen()
                    print("-" * 60)
                    print(f"AGRI-LOOP SISTEM MONITORU | {current_time}")
                    print("-" * 60)

                    print("URUN YONETIMI")
                    print(f" > Konveyor Bant    : {motor_status_str}")
                    print(f" > Yem Silo Doluluk : %{fill_percent} {draw_progress_bar(fill_percent)}")
                    print(f" > Su Seviyesi      : {water_status}")
                    print("-" * 60)

                    print("ORTAM DEGERLERI")
                    print(f" > Sicaklik         : {temp:.1f} C")
                    print(f" > Nem              : {hum:.1f} %")
                    print(f" > Aydinlatma       : {light_status} (Sensor: {light_val})")
                    print("-" * 60)

                    print("GUVENLIK DURUMU")
                    if motion == 1:
                        print(" [!] UYARI: BOLGEDE HAREKET ALGILANDI")
                    else:
                        print(" > Hareket          : TEMIZ")
                    
                    if sound > 600:
                        print(" [!] UYARI: YUKSEK SES DUZEYI TESPIT EDILDI")
                    else:
                        print(" > Ses Duzeyi       : NORMAL")
                    
                    print("-" * 60)
                    print("Cikis icin CTRL+C yapiniz...")

                except ValueError:
                    # Bozuk veri paketi gelirse gormezden gel
                    pass

        except KeyboardInterrupt:
            print("\nSistem kullanici tarafindan kapatildi.")
            if ser.is_open:
                ser.close()
            break
        except Exception as e:
            print(f"\n[SISTEM HATASI]: {e}")
            break

if __name__ == "__main__":
    main()