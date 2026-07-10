import requests
import json

url = "http://localhost:8000/api/auth/signup"
payload = {
    "email": "test@example.com",
    "password": "TestPassword123!",
    "full_name": "Test User",
    "date_of_birth": "2000-01-01",
    "phone_number": "1234567890",
    "gender": "Male"
}

try:
    response = requests.post(url, json=payload, timeout=10)
    print(f"Status Code: {response.status_code}")
    print(f"Response Headers: {dict(response.headers)}")
    print(f"Response Body: {response.text}")
    if response.status_code != 200:
        try:
            print(f"JSON: {response.json()}")
        except:
            pass
except Exception as e:
    print(f"Error: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()
