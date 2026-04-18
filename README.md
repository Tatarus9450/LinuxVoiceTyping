# Phim Thai Mai Pen

Linux Thai Voice Typing HotKey

ระบบพิมพ์ด้วยเสียงบน Linux สำหรับพูดภาษาไทย, ไทยปนอังกฤษ, และแปลไทยเป็นอังกฤษก่อนพิมพ์ลงแอปที่กำลังใช้งานอยู่

Linux voice typing for Thai speech, Thai-English mixed speech, and Thai-to-English translation before inserting text into the app you are currently using.

ใช้ [Typhoon ASR](https://github.com/scb-10x/typhoon-asr) เป็น backend หลัก และรันงานถอดเสียงกับแปลภาษาในเครื่องของคุณเอง

It uses [Typhoon ASR](https://github.com/scb-10x/typhoon-asr) as the main backend and runs transcription plus translation locally on your machine.

---

## โปรแกรมนี้มีประโยชน์อะไร / Why Use It

1. เพิ่มระบบการพิมพ์ด้วยเสียงบน Linux ให้ฟีลใกล้เคียงกับที่หลายคนคุ้นจาก Windows Adds voice typing to Linux with a feel closer to what many people know from Windows.
2. เหมาะกับคนไทยสุด ๆ และพยายามให้ใช้งานได้กับแทบทุกหน้าต่างทุกโปรแกรมในเครื่องนี้ แต่อาจมีบัคหรือแอปบางตัวดื้อบ้าง Very Thai-focused and intended to work across almost any app window on your machine, although some bugs or stubborn apps are expected.
3. มีบัคแน่นอน เอาไว้ค่อยแก้ Bugs definitely exist. We can fix them later.

---

## ติดตั้ง / Install

```bash
git clone https://github.com/Tatarus9450/PhimThaiMaiPen.git
cd PhimThaiMaiPen
chmod +x install.sh
./install.sh
```

ตอนรัน `./install.sh` ให้ตอบเป็นตัวเลข:

When `./install.sh` starts, answer with a number:

- `1` ติดตั้งหรือซ่อมโปรแกรมนี้ - install or repair the program
- `2` ถอนการติดตั้ง - uninstall

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

## หลักการทำงาน / How It Works

1. ผู้ใช้วางเคอร์เซอร์ไว้ในแอปที่ต้องการพิมพ์ แล้วกด `Meta + H` เพื่อเริ่มทำงาน. The user places the cursor in the target app and presses `Meta + H` to begin.
2. โปรแกรมรับคำสั่งจาก hotkey แล้วเริ่มอัดเสียงจากไมโครโฟนผ่าน `arecord`. The app receives the hotkey trigger and starts recording from the microphone through `arecord`.
3. ถ้าผู้ใช้กด `Meta + Shift + H` ก่อนหรือระหว่างใช้งาน โปรแกรมจะเปลี่ยนโหมดเป็น `Smart Mix`, `Raw`, หรือ `TH to ENG`. If the user presses `Meta + Shift + H` before or between runs, the app switches the active profile to `Smart Mix`, `Raw`, or `TH to ENG`.
4. เมื่อผู้ใช้กด `Meta + H` อีกครั้ง โปรแกรมจะหยุดอัดเสียงแล้วส่งไฟล์เสียงไปให้ local worker. When the user presses `Meta + H` again, the app stops recording and sends the audio file to the local worker.
5. worker จะเตรียมไฟล์เสียงให้อยู่ในรูปแบบที่เหมาะกับโมเดล แล้วส่งเข้า Typhoon ASR เพื่อถอดเสียง. The worker normalizes the audio into the model-ready format and sends it to Typhoon ASR for transcription.
6. ถ้าอยู่ในโหมด `Smart Mix` ระบบจะจัดรูปข้อความและใช้ replacement rules เพิ่มเติม. If the active profile is `Smart Mix`, the app formats the text and applies replacement rules.
7. ถ้าอยู่ในโหมด `TH to ENG` ระบบจะถอดเสียงภาษาไทยก่อน แล้วแปลผลลัพธ์เป็นภาษาอังกฤษในเครื่อง. If the active profile is `TH to ENG`, the app first transcribes Thai speech and then translates the result to English locally.
8. เมื่อได้ข้อความสุดท้ายแล้ว โปรแกรมจะคัดลอกข้อความลง clipboard ก่อน แล้วพยายาม paste กลับเข้าแอปที่กำลังโฟกัสอยู่; ถ้า paste ไม่สำเร็จ ข้อความจะยังค้างอยู่ใน clipboard ให้ผู้ใช้ paste เอง. Once the final text is ready, the app copies it to the clipboard first and then tries to paste it back into the focused application; if the paste fails, the text remains in the clipboard for manual paste.

---

## หมายเหตุ / Quick Notes

- runtime ของการถอดเสียงและแปลภาษาเป็น local. Runtime transcription and translation are local.
- บน Wayland บางแอปอาจต้อง paste เองจาก clipboard ถ้า auto-paste ถูกบล็อก. On Wayland, some apps may require manual paste from the clipboard if auto-paste is blocked.
- ถ้า auto-paste สำเร็จ โปรแกรมจะคืนค่า clipboard เดิม; ถ้า auto-paste ไม่สำเร็จ ข้อความล่าสุดจะค้างอยู่ใน clipboard ให้ paste เอง. If auto-paste succeeds, the app restores the previous clipboard contents; if auto-paste fails, the latest text remains in the clipboard for manual paste.
- ถ้า hotkey ยังไม่ทำงานหลังติดตั้ง ให้ logout/login ใหม่ก่อน. If shortcuts do not work immediately after install, try logging out and back in first.

---

## License

MIT
