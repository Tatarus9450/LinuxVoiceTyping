import tkinter as tk
from pathlib import Path
import time
import os

STATUS_FILE = Path("/tmp/voice_agent_status")
LANG_FILE = Path("/tmp/voice_agent_lang")

class ModernPopup(tk.Tk):
    def __init__(self):
        super().__init__()
        self.overrideredirect(True)
        self.attributes('-topmost', True)
        self.config(bg='black')
        
        # Transparent background hack (linux) - might not work everywhere but worth a try
        # self.attributes('-alpha', 0.8) 

        screen_width = self.winfo_screenwidth()
        screen_height = self.winfo_screenheight()
        
        width = 320
        height = 80
        x = (screen_width - width) // 2
        y = (screen_height - height) // 2 # Center
        # y = screen_height - height - 100 # Bottom

        self.geometry(f"{width}x{height}+{x}+{y}")

        # Main Frame with rounded look (simulated with canvas or padding)
        self.canvas = tk.Canvas(self, width=width, height=height, bg='#1e1e1e', highlightthickness=0)
        self.canvas.pack(fill='both', expand=True)

        # Draw rounded rect bg
        self.round_rect(5, 5, width-5, height-5, radius=20, fill='#2d2d2d', outline='#4a4a4a')

        # Status Dot
        self.dot = self.canvas.create_oval(30, 32, 46, 48, fill='#ff4444', outline='')
        
        # Text
        self.label_id = self.canvas.create_text(60, 40, anchor='w', text="Initializing...", fill='white', font=('Helvetica', 14, 'bold'))
        
        # Language
        self.lang_id = self.canvas.create_text(width-30, 40, anchor='e', text="", fill='#aaaaaa', font=('Helvetica', 12))

        self.pulsing = False
        self.pulse_step = 0
        self.update_status()

    def round_rect(self, x1, y1, x2, y2, radius=25, **kwargs):
        points = [x1+radius, y1,
                  x2-radius, y1,
                  x2, y1,
                  x2, y1+radius,
                  x2, y2-radius,
                  x2, y2,
                  x2-radius, y2,
                  x1+radius, y2,
                  x1, y2,
                  x1, y2-radius,
                  x1, y1+radius,
                  x1, y1]
        return self.canvas.create_polygon(points, **kwargs, smooth=True)

    def update_status(self):
        # Read status
        status = "Waiting..."
        color = "#888888"
        dot_color = "#444444"
        self.pulsing = False

        if STATUS_FILE.exists():
            try:
                status_text = STATUS_FILE.read_text().strip()
                if status_text == "recording":
                    status = "Listening..."
                    color = "white"
                    dot_color = "#ff4444" # Red
                    self.pulsing = True
                elif status_text == "transcribing":
                    status = "Thinking..."
                    color = "#00ddee" # Cyan
                    dot_color = "#00ddee"
                    self.pulsing = True
                elif status_text == "typing":
                    status = "Typing..."
                    color = "#00ff88" # Green
                    dot_color = "#00ff88"
            except:
                pass
        
        # Read Language
        lang = ""
        if LANG_FILE.exists():
            try:
                l = LANG_FILE.read_text().strip()
                if l == "th": lang = "🇹🇭 TH"
                elif l == "en": lang = "🇺🇸 EN"
            except:
                pass

        self.canvas.itemconfig(self.label_id, text=status, fill=color)
        self.canvas.itemconfig(self.lang_id, text=lang)
        
        # Animation
        if self.pulsing:
            self.pulse_step += 0.2
            import math
            opacity = (math.sin(self.pulse_step) + 1) / 2 # 0 to 1
            # Interpolate color helper? Tkinter colors are hex.
            # Simple toggle for now or constant glow
            if self.pulse_step % 2 > 1:
                self.canvas.itemconfig(self.dot, fill=dot_color)
            else:
                 # Dimmer
                self.canvas.itemconfig(self.dot, fill=self.adjust_color_brightness(dot_color, 0.5))
        else:
            self.canvas.itemconfig(self.dot, fill=dot_color)

        self.after(100, self.update_status)

    def adjust_color_brightness(self, hex_color, factor):
        # Very basic hex dimmer
        if not hex_color.startswith('#') or len(hex_color) != 7: return hex_color
        r = int(hex_color[1:3], 16)
        g = int(hex_color[3:5], 16)
        b = int(hex_color[5:7], 16)
        r = int(r * factor)
        g = int(g * factor)
        b = int(b * factor)
        return f"#{r:02x}{g:02x}{b:02x}"

if __name__ == "__main__":
    app = ModernPopup()
    app.mainloop()
