import tkinter as tk
from pathlib import Path
import math

STATUS_FILE = Path("/tmp/voice_agent_status")
LANG_FILE = Path("/tmp/voice_agent_lang")

# ── Color Palette ──
BG         = "#111111"
SURFACE    = "#1a1a1a"
BORDER     = "#2a2a2a"
TEXT_DIM   = "#555555"
TEXT_MID   = "#888888"

COLORS = {
    "recording":    {"dot": "#ff3b30", "text": "#ffffff",  "label": "Listening",  "glow": "#ff3b30"},
    "transcribing": {"dot": "#0a84ff", "text": "#0a84ff",  "label": "Thinking",   "glow": "#0a84ff"},
    "typing":       {"dot": "#30d158", "text": "#30d158",  "label": "Typing",     "glow": "#30d158"},
}


class MinimalPopup(tk.Tk):
    def __init__(self):
        super().__init__()

        # ── Window setup ──
        self.overrideredirect(True)
        self.attributes("-topmost", True)
        self.config(bg=BG)

        # Dimensions
        self.w = 200
        self.h = 52

        # Position: left-center of screen
        screen_w = self.winfo_screenwidth()
        screen_h = self.winfo_screenheight()
        x = 32  # 32px from left edge
        y = (screen_h - self.h) // 2

        self.geometry(f"{self.w}x{self.h}+{x}+{y}")

        # Try transparency
        try:
            self.attributes("-alpha", 0.92)
        except:
            pass

        # ── Canvas ──
        self.canvas = tk.Canvas(
            self, width=self.w, height=self.h,
            bg=BG, highlightthickness=0, bd=0
        )
        self.canvas.pack(fill="both", expand=True)

        # Rounded background
        self._rounded_rect(2, 2, self.w - 2, self.h - 2, r=16, fill=SURFACE, outline=BORDER)

        # Status indicator dot
        dot_cx, dot_cy = 24, self.h // 2
        self.dot = self.canvas.create_oval(
            dot_cx - 5, dot_cy - 5, dot_cx + 5, dot_cy + 5,
            fill=TEXT_DIM, outline=""
        )

        # Glow ring (outer dim circle for pulse effect)
        self.glow = self.canvas.create_oval(
            dot_cx - 9, dot_cy - 9, dot_cx + 9, dot_cy + 9,
            fill="", outline=TEXT_DIM, width=1
        )

        # Status label
        self.label = self.canvas.create_text(
            42, self.h // 2, anchor="w",
            text="…", fill=TEXT_DIM,
            font=("Helvetica Neue", 13)
        )

        # Language badge (right side)
        self.lang_label = self.canvas.create_text(
            self.w - 16, self.h // 2, anchor="e",
            text="", fill=TEXT_MID,
            font=("Helvetica Neue", 10)
        )

        # Animation state
        self.tick = 0.0
        self._update()

    def _rounded_rect(self, x1, y1, x2, y2, r=20, **kwargs):
        points = [
            x1 + r, y1,
            x2 - r, y1,
            x2, y1, x2, y1 + r,
            x2, y2 - r,
            x2, y2, x2 - r, y2,
            x1 + r, y2,
            x1, y2, x1, y2 - r,
            x1, y1 + r,
            x1, y1,
        ]
        self.canvas.create_polygon(points, smooth=True, **kwargs)

    def _dim(self, hex_color, factor):
        """Dim a hex color by factor (0-1)."""
        if not hex_color.startswith("#") or len(hex_color) != 7:
            return hex_color
        r = int(int(hex_color[1:3], 16) * factor)
        g = int(int(hex_color[3:5], 16) * factor)
        b = int(int(hex_color[5:7], 16) * factor)
        return f"#{min(r,255):02x}{min(g,255):02x}{min(b,255):02x}"

    def _update(self):
        # ── Read status ──
        status_key = None
        if STATUS_FILE.exists():
            try:
                status_key = STATUS_FILE.read_text().strip()
            except:
                pass

        cfg = COLORS.get(status_key)

        if cfg:
            self.canvas.itemconfig(self.label, text=cfg["label"], fill=cfg["text"])

            # Pulse animation
            self.tick += 0.12
            pulse = (math.sin(self.tick) + 1) / 2  # 0..1

            dot_color = cfg["dot"]
            dimmed = self._dim(dot_color, 0.3 + 0.7 * pulse)
            glow_dim = self._dim(cfg["glow"], 0.15 + 0.25 * pulse)

            self.canvas.itemconfig(self.dot, fill=dimmed)
            self.canvas.itemconfig(self.glow, outline=glow_dim, width=1)
        else:
            self.canvas.itemconfig(self.label, text="…", fill=TEXT_DIM)
            self.canvas.itemconfig(self.dot, fill=TEXT_DIM)
            self.canvas.itemconfig(self.glow, outline=BG)

        # ── Read language ──
        lang_text = ""
        if LANG_FILE.exists():
            try:
                l = LANG_FILE.read_text().strip()
                if l == "th":
                    lang_text = "TH"
                elif l == "en":
                    lang_text = "EN"
            except:
                pass
        self.canvas.itemconfig(self.lang_label, text=lang_text)

        self.after(80, self._update)


if __name__ == "__main__":
    app = MinimalPopup()
    app.mainloop()
