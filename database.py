# Dosya: backend/database.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Veritabanı dosyasının adı 'farm.db' olacak
SQLALCHEMY_DATABASE_URL = "sqlite:///./farm.db"

# Motoru (Engine) çalıştırıyoruz. 
# check_same_thread=False ayarı SQLite için gereklidir (FastAPI multi-thread çalıştığı için).
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Veritabanı oturumu (Session) oluşturucu
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base sınıfı: Tüm veritabanı tablolarımız bu sınıftan türeyecek.
Base = declarative_base()