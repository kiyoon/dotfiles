import os
import time
import subprocess

# 1️⃣ Take a screenshot and copy directly to clipboard
subprocess.Popen("scrot - | convert png:- -resize '1280x720>' png:- | xclip -selection clipboard -t image/png -i", shell=True)

# 2️⃣ Focus or open Chrome
chrome_running = os.system("wmctrl -lx | grep -q 'google-chrome.Google-chrome'") == 0
if not chrome_running:
    subprocess.Popen(["google-chrome", "--new-window"])
    # Wait until Chrome appears in window list
    for _ in range(30):  # up to 3 seconds
        if os.system("wmctrl -lx | grep -q 'google-chrome.Google-chrome'") == 0:
            break
        time.sleep(0.1)
else:
    os.system("wmctrl -xa google-chrome.Google-chrome")

# 3️⃣ New tab + navigate
keyboard.send_keys("<ctrl>+t")
time.sleep(0.2)
keyboard.send_keys("https://translate.google.com/?sl=auto&tl=en&op=images")
keyboard.send_keys("<enter>")

# 4️⃣ Paste
time.sleep(0.5)
keyboard.send_keys("<ctrl>+v")
time.sleep(0.5)
keyboard.send_keys("<ctrl>+v")
time.sleep(0.5)
keyboard.send_keys("<ctrl>+v")
time.sleep(0.5)
keyboard.send_keys("<ctrl>+v")
time.sleep(0.5)
keyboard.send_keys("<ctrl>+v")
time.sleep(0.5)
keyboard.send_keys("<ctrl>+v")