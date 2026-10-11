import wave
import math
import struct
import os

def create_safe_soft_radar_ping(output_path="audio/sfx_radar_ping.wav"):
    sample_rate = 44100
    duration = 0.12       # 120 ms (rápido e discreto)
    base_freq = 920.0     # Frequência quente/aveludada (sem agudo cortante)
    
    # LIMITADOR RÍGIDO DE AMPLITUDE:
    # 0.22 garante que o som fique com pico em ~ -13 dBFS (impossível clipar no Master)
    max_amplitude = 0.22  
    
    num_samples = int(sample_rate * duration)
    attack_samples = int(sample_rate * 0.006)  # 6ms de ataque suave (elimina estalo inicial)
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with wave.open(output_path, "w") as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit PCM
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            
            # 1. Envoltória de Ataque Suave (Anti-Click)
            if i < attack_samples:
                attack = float(i) / float(attack_samples)
            else:
                attack = 1.0
                
            # 2. Decaimento exponencial macio
            decay = math.exp(-24.0 * t)
            envelope = attack * decay
            
            # 3. Modulação de tom sutil e orgânica
            freq = base_freq + (180.0 * (1.0 - (t / duration)))
            sample_val = math.sin(2.0 * math.pi * freq * t) * envelope * max_amplitude
            
            # 4. Trava rígida de segurança (Hard Limiter) antes de empacotar
            sample_clamped = max(-1.0, min(1.0, sample_val))
            packed_sample = struct.pack("<h", int(sample_clamped * 32767.0))
            wav_file.writeframesraw(packed_sample)
            
    print(f"✅ Áudio de radar anti-estouro gerado em: {output_path}")

if __name__ == "__main__":
    create_safe_soft_radar_ping()
