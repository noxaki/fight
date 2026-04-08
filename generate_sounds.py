import wave
import struct
import math
import random

def generate_jump(filename):
    sample_rate = 44100
    duration = 0.3
    num_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            # Frequency sweeps up
            freq = 300 + 400 * t
            val = math.sin(2.0 * math.pi * freq * t)
            # Envelope (fade out)
            env = 1.0 - (t / duration)
            sample = int(val * env * 32767.0)
            wav_file.writeframes(struct.pack('h', sample))

def generate_kick(filename):
    sample_rate = 44100
    duration = 0.2
    num_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            # Burst of noise followed by sine thump
            if t < 0.05:
                val = random.uniform(-1.0, 1.0)
            else:
                freq = max(50, 150 - 500 * (t - 0.05))
                val = math.sin(2.0 * math.pi * freq * (t - 0.05))
            
            # Envelope
            env = math.exp(-t * 15)
            sample = int(val * env * 32767.0)
            wav_file.writeframes(struct.pack('h', sample))

generate_jump('assets/sounds/jump.wav')
generate_kick('assets/sounds/kick.wav')
