import hashlib

files = [
    "Masmak_Fort_(12753717253).jpg",
    "King_Fahd's_Fountain_Jeddah_Fountain_(5129797428).jpg",
]
for name in files:
    h = hashlib.md5(name.encode()).hexdigest()
    print(f"https://upload.wikimedia.org/wikipedia/commons/{h[0]}/{h[0:2]}/{name}")
