import requests
# Test API health
try:
    resp = requests.get("http://localhost:8000/")
    print(f"Root endpoint: {resp.status_code}")
    if resp.status_code == 200:
        print(f"Response: {resp.json()}")
except Exception as e:
    print(f"Error: {e}")
