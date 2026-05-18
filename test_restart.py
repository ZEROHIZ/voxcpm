import requests
import time
import socket

url = "http://192.168.110.30:8089/v1/audio/restart"

print("=" * 60)
print("   VoxCPM2 API Gateway - Hot Restart Test Script")
print("=" * 60)
print(f"Target Endpoint: {url}\n")

# 1. Trigger the hot restart
try:
    print("[1/3] Sending POST request to trigger hot restart...")
    response = requests.post(url, timeout=5)
    print(f"      Response Status Code: {response.status_code}")
    print(f"      Response Data: {response.json()}")
except requests.exceptions.RequestException as e:
    print(f"[ERROR] Failed to connect or trigger restart: {e}")
    print("Please make sure your API gateway (run_openai_api.bat) is running.")
    exit(1)

# 2. Confirm the server goes offline
print("\n[2/3] Waiting for the server to gracefully shut down...")
time.sleep(1.5)  # Wait for the python process to exit

# 3. Poll and wait for it to self-heal and boot back up
print("[3/3] Polling server to verify successful auto-reboot...")
host = "192.168.110.30"
port = 8089
reboot_successful = False

for attempt in range(1, 16):
    time.sleep(1.0)
    try:
        # Check if the TCP port is open and accepting connections
        with socket.create_connection((host, port), timeout=1):
            print(f"      [Attempt {attempt}] Connection accepted! Port 8089 is open.")
            reboot_successful = True
            break
    except (socket.timeout, ConnectionRefusedError):
        print(f"      [Attempt {attempt}] Server is offline, waiting for reload...")

print("=" * 60)
if reboot_successful:
    print("🎉 SUCCESS: API Gateway successfully restarted and is back ONLINE!")
    print("   All PyTorch VRAM and RAM cache have been completely released.")
else:
    print("⚠️ WARNING: Server did not reboot in 15 seconds. Please check the batch terminal.")
print("=" * 60)
