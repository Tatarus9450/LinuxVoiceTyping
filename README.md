# Linux Voice Typing

ระบบพิมพ์ด้วยเสียงบน Linux สำหรับพูดภาษาไทย, ไทยปนอังกฤษ, และแปลไทยเป็นอังกฤษก่อนพิมพ์ลงแอปที่กำลังใช้งานอยู่

Linux voice typing for Thai speech, Thai-English mixed speech, and Thai-to-English translation before inserting text into the app you are currently using.

ใช้ [Typhoon ASR](https://github.com/scb-10x/typhoon-asr) เป็น backend หลัก และรันงานถอดเสียงกับแปลภาษาในเครื่องของคุณเอง

It uses [Typhoon ASR](https://github.com/scb-10x/typhoon-asr) as the main backend and runs transcription plus translation locally on your machine.

---

## โปรแกรมนี้มีประโยชน์อะไร / Why Use It

- พิมพ์ข้อความด้วยเสียงได้เร็วขึ้น โดยไม่ต้องสลับไปเปิดเว็บถอดเสียง. Type faster with your voice without switching to a web transcription tool.
- เหมาะกับงานพูดภาษาไทยและคำอังกฤษปนไทย. Good for Thai dictation and Thai speech with mixed English words.
- มีโหมดแปลไทยเป็นอังกฤษให้เลย. Includes a Thai-to-English output mode.
- ใช้งานได้ทั้ง X11 และ Wayland ตาม session ที่กำลังใช้งานอยู่. Works with either X11 or Wayland based on your current session.

---

## ติดตั้ง / Install

```bash
git clone https://github.com/Tatarus9450/LinuxVoiceTyping.git
cd LinuxVoiceTyping
chmod +x install.sh
./install.sh
```

ตอนรัน `./install.sh` ให้ตอบเป็นตัวเลข:

When `./install.sh` starts, answer with a number:

- `1` ติดตั้งหรือซ่อมโปรแกรมนี้
- `2` ถอนการติดตั้ง

- `1` install or repair the project
- `2` uninstall it

ถ้าคุณเปลี่ยนจาก X11 ไป Wayland หรือเปลี่ยน desktop environment ภายหลัง ให้รัน `./install.sh` ใหม่อีกครั้ง

If you later switch between X11 and Wayland, or change desktop environments, run `./install.sh` again.

ถ้าต้องการตรวจระบบหลังติดตั้งเอง ให้รัน `python3 self_check.py`

If you want to run a manual health check after installation, run `python3 self_check.py`

---

## วิธีใช้งาน / How To Use

| Shortcut | Action |
| :--- | :--- |
| `Meta + H` | เริ่มหรือหยุดการอัดเสียง / Start or stop recording |
| `Meta + Shift + H` | เปลี่ยนโหมดการพิมพ์ / Change the dictation mode |

วิธีใช้งาน:

Usage flow:

1. วางเคอร์เซอร์ในแอปที่ต้องการพิมพ์. Place your cursor in the target app.
2. ถ้าต้องการ เปลี่ยนโหมดด้วย `Meta + Shift + H`. If needed, change the mode with `Meta + Shift + H`.
3. กด `Meta + H` เพื่อเริ่มอัดเสียง. Press `Meta + H` to start recording.
4. พูดใส่ไมโครโฟน. Speak into your microphone.
5. กด `Meta + H` อีกครั้งเพื่อหยุดอัด. Press `Meta + H` again to stop recording.
6. ระบบจะถอดเสียงหรือแปลภาษา แล้วพิมพ์กลับเข้าแอปให้อัตโนมัติ. The app transcribes or translates your speech and inserts the text back into the target app.

---

## โหมดการใช้งาน / Modes

- `Smart Mix` ใช้สำหรับพูดไทยที่มีคำอังกฤษปน. For Thai speech with mixed English terms.
- `Raw` ใช้เมื่ออยากได้ข้อความแบบตรงที่สุด. For the most direct raw transcription.
- `TH to ENG` ใช้เมื่อพูดภาษาไทย แต่ต้องการผลลัพธ์เป็นภาษาอังกฤษ. For speaking Thai but getting English output.

ใน popup:

In the popup:

- `MIX` = `Smart Mix`
- `RAW` = `Raw`
- `TH>ENG` = `TH to ENG`

---

## หมายเหตุสั้น ๆ / Quick Notes

- runtime ของการถอดเสียงและแปลภาษาเป็น local. Runtime transcription and translation are local.
- บน Wayland บางแอปอาจต้อง paste เองจาก clipboard ถ้า auto-paste ถูกบล็อก. On Wayland, some apps may require manual paste from the clipboard if auto-paste is blocked.
- ถ้า hotkey ยังไม่ทำงานหลังติดตั้ง ให้ logout/login ใหม่ก่อน. If shortcuts do not work immediately after install, try logging out and back in first.

---

## License

MIT
