"""Tira quadros de um vídeo para conferência: python quadros.py video.mp4 3 14 27"""
import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg

video = Path(sys.argv[1])
for s in sys.argv[2:]:
    out = Path(__file__).parent / "work" / f"q_{video.stem[:10]}_{s}.png"
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-ss", s, "-i", str(video),
                    "-frames:v", "1", str(out)], check=True)
    print(out)
