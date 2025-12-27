import base64
import io
from datetime import datetime
from typing import Tuple

import numpy as np

try:
    from pydub import AudioSegment
    import librosa
    from tensorflow.keras.models import load_model
except Exception as e:
    # Lazy import errors will be raised when used
    AudioSegment = None
    librosa = None
    load_model = None

MODEL_PATH = "animal_security_model.h5"
_model = None


def get_model():
    global _model
    if _model is None:
        if load_model is None:
            raise RuntimeError("TensorFlow not available. Install tensorflow.")
        _model = load_model(MODEL_PATH)
    return _model


def _load_audio_from_base64(audio_b64: str) -> Tuple[np.ndarray, int]:
    import tempfile
    import os
    
    raw = base64.b64decode(audio_b64)
    
    # Temp dosyaya yaz
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            tmp.write(raw)
            tmp_path = tmp.name
        
        print(f"[Audio] Temp dosya: {tmp_path}, size: {len(raw)} bytes")
        
        # soundfile ile yükle (WAV format)
        try:
            import soundfile as sf
            y, sr = sf.read(tmp_path)
            print(f"[Audio] soundfile ile yüklendi: shape={y.shape}, sr={sr}")
            if y.ndim == 2:
                y = y.mean(axis=1)
        except Exception as e:
            print(f"[Audio] soundfile hatası: {e}, librosa deniyor...")
            y, sr = librosa.load(tmp_path, sr=16000, mono=True)
            print(f"[Audio] librosa ile yüklendi: shape={y.shape}, sr={sr}")
        
        # Temp dosyayı sil
        os.unlink(tmp_path)
        
        return y.astype(np.float32), sr
    except Exception as e:
        print(f"[Audio] Load hatası: {e}")
        if 'tmp_path' in locals():
            try:
                os.unlink(tmp_path)
            except:
                pass
        raise


def _extract_features(y: np.ndarray, sr: int, target_sr: int = 16000) -> np.ndarray:
    if librosa is None:
        raise RuntimeError("librosa not available. Install librosa.")
    
    # Ses boş mu kontrol et
    if len(y) == 0 or np.max(np.abs(y)) < 1e-6:
        print("[Audio] Warning: audio is silent or empty, creating dummy features")
        # Boş ses için default feature
        log_S = np.zeros((128, 128), dtype=np.float32)
    else:
        # Resample
        if sr != target_sr:
            y = librosa.resample(y, orig_sr=sr, target_sr=target_sr)
        # Normalize
        y = y / (np.max(np.abs(y)) + 1e-9)
        # Compute log-mel spectrogram
        S = librosa.feature.melspectrogram(y=y, sr=target_sr, n_mels=128, fmax=8000)
        log_S = librosa.power_to_db(S, ref=np.max)
        # Pad/trim to (128,128)
        target_frames = 128
        if log_S.shape[1] < target_frames:
            pad = target_frames - log_S.shape[1]
            log_S = np.pad(log_S, ((0, 0), (0, pad)), mode="constant")
        else:
            log_S = log_S[:, :target_frames]
    
    # Final shape (128,128,1)
    feat = log_S.astype(np.float32)
    feat = (feat - np.mean(feat)) / (np.std(feat) + 1e-6)
    feat = np.expand_dims(feat, axis=-1)
    return feat


def _fit_to_input(x: np.ndarray, input_shape) -> np.ndarray:
    """Fit features to model's expected input shape."""
    # input_shape includes batch dim: (None, H, W, C) or similar
    if len(input_shape) == 4:
        H, W, C = input_shape[1], input_shape[2], input_shape[3]
        xH, xW, xC = x.shape
        # Resize/pad channels
        if xC != C:
            # If model expects 3 channels, tile; if 1, squeeze
            if C == 3 and xC == 1:
                x = np.repeat(x, 3, axis=-1)
            elif C == 1 and xC == 3:
                x = x[..., :1]
        # Resize to HxW if needed
        if xH != H or xW != W:
            # Simple center crop/pad
            x = x[:H, :W, ...]
            if x.shape[0] < H or x.shape[1] < W:
                padH = max(0, H - x.shape[0])
                padW = max(0, W - x.shape[1])
                x = np.pad(x, ((0, padH), (0, padW), (0, 0)), "constant")
        # Add batch dim
        x = np.expand_dims(x, axis=0)
        return x
    elif len(input_shape) == 3:
        T, F = input_shape[1], input_shape[2]
        # Convert (128,128,1) -> (T,F) if necessary
        x2 = x.squeeze()
        # Ensure orientation matches (time, features)
        if x2.shape[0] == F and x2.shape[1] == T:
            x2 = x2.T
        # Pad/trim
        x2 = x2[:T, :F]
        if x2.shape[0] < T or x2.shape[1] < F:
            padT = max(0, T - x2.shape[0])
            padF = max(0, F - x2.shape[1])
            x2 = np.pad(x2, ((0, padT), (0, padF)), "constant")
        x2 = np.expand_dims(x2, axis=0)
        return x2
    else:
        # Fallback: add batch dim
        return np.expand_dims(x, axis=0)


def analyze(audio_b64: str) -> Tuple[str, float]:
    try:
        model = get_model()
        y, sr = _load_audio_from_base64(audio_b64)
        print(f"[Audio] Raw audio shape: {y.shape}, SR: {sr}")
        
        feat = _extract_features(y, sr)
        print(f"[Audio] Features shape: {feat.shape}")
        
        x = _fit_to_input(feat, model.input_shape)
        print(f"[Audio] Input to model shape: {x.shape}, model expects: {model.input_shape}")
        
        pred = model.predict(x, verbose=0)
        print(f"[Audio] Prediction output: {pred}, shape: {pred.shape}")
        
        # Handle multi-class classification (8 classes)
        if pred.ndim == 2 and pred.shape[1] > 2:
            # Multi-class: group into binary (danger vs safe)
            # Dangerous classes: 0=person, 1=wolf, 2=dog, 3=bear, 4=cat (assuming)
            # Safe classes: 5=silence, 6=wind, 7=rain (assuming)
            dangerous_classes = [0, 1, 2, 3, 4]
            safe_classes = [5, 6, 7]
            
            # Sum probabilities by group
            danger_conf = sum(pred[0, i] for i in dangerous_classes if i < len(pred[0]))
            safe_conf = sum(pred[0, i] for i in safe_classes if i < len(pred[0]))
            
            # Normalize to sum to 1
            total = danger_conf + safe_conf
            if total > 0:
                danger_conf /= total
                safe_conf /= total
            
            # Decide based on normalized scores
            label = "danger" if danger_conf > safe_conf else "safe"
            confidence = max(danger_conf, safe_conf)
            
            print(f"[Audio] Danger score: {danger_conf:.2%}, Safe score: {safe_conf:.2%}, label: {label}")
        # Binary classification
        elif pred.ndim == 2 and pred.shape[1] == 2:
            danger_conf = float(pred[0, 0])
            safe_conf = float(pred[0, 1])
            label = "danger" if danger_conf >= safe_conf else "safe"
            confidence = max(danger_conf, safe_conf)
        # Single output (sigmoid)
        else:
            val = float(pred.squeeze()) if isinstance(pred.squeeze(), (int, float, np.number)) else float(pred[0, 0])
            label = "danger" if val >= 0.5 else "safe"
            confidence = val if label == "danger" else 1.0 - val
        
        print(f"[Audio] Final result: {label}, confidence: {confidence:.2%}")
        return label, confidence
    except Exception as e:
        print(f"[Audio] Analyze error: {e}", flush=True)
        import traceback
        traceback.print_exc()
        raise


def now_timestamp() -> datetime:
    return datetime.now()
