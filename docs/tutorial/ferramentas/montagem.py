"""Montagem (ffmpeg): corpo do módulo com voz e legenda + capa animada antes; cartões de abertura/encerramento."""
import re
import subprocess
from pathlib import Path

import imageio_ffmpeg

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
BASE = Path(__file__).parent
TMP = BASE / "work"
ARTE = BASE.parent / "arte"
SAIDA = BASE / "videos"
# Mesmos parâmetros em todos os clipes: o concat final copia sem recodificar.
VIDEO = ["-r", "30", "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p"]
AUDIO = ["-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-ac", "2"]
# BorderStyle=3: caixa opaca atrás do texto (a cor da caixa é a OutlineColour; Outline = margem interna).
LEGENDA = ("FontName=Segoe UI Semibold,FontSize=10,PrimaryColour=&H00FFFFFF,OutlineColour=&H30111111,"
           "BorderStyle=3,Outline=5,Shadow=0,MarginV=22,Alignment=2")


def duracao(arq):
    r = subprocess.run([FFMPEG, "-i", str(arq)], capture_output=True, text=True, encoding="utf-8", errors="ignore")
    h, mi, s = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr).groups()
    return int(h) * 3600 + int(mi) * 60 + float(s)


def _rodar(cmd):
    r = subprocess.run(cmd, cwd=TMP, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[-1500:])


def cartao(png, segundos, saida, zoom=True):
    """Imagem parada com leve aproximação (Ken Burns) e fade, com áudio mudo."""
    z = f"zoompan=z='min(zoom+0.0006,1.04)':d={int(segundos * 30)}:s=1280x800:fps=30," if zoom else "fps=30,"
    filtro = (f"[0:v]scale=1280:800,{z}format=yuv420p,fade=t=in:st=0:d=0.4,fade=t=out:st={segundos - 0.5}:d=0.5[v]")
    _rodar([FFMPEG, "-y", "-loop", "1", "-t", str(segundos), "-i", str(png), "-f", "lavfi", "-t", str(segundos),
            "-i", "anullsrc=r=48000:cl=stereo", "-filter_complex", filtro, "-map", "[v]", "-map", "1:a",
            "-t", str(segundos), *VIDEO, *AUDIO, str(saida)])
    return saida


def montar(m, video, inicio):
    audio = TMP / f"{m['id']}.mp3"
    acao = duracao(video) - inicio
    dur = max(duracao(audio) + 1.2, acao)  # nunca corta a ação nem a fala
    corpo = TMP / f"corpo_{m['id']}.mp4"
    filtro = (f"tpad=stop_mode=clone:stop_duration=30,fade=t=in:st=0:d=0.4,"
              f"fade=t=out:st={dur - 0.5:.2f}:d=0.5,subtitles={m['id']}.srt:force_style='{LEGENDA}'")
    _rodar([FFMPEG, "-y", "-ss", f"{inicio:.2f}", "-i", str(video), "-i", audio.name, "-vf", filtro,
            "-af", f"apad,afade=t=out:st={dur - 0.5:.2f}:d=0.5", "-t", f"{dur:.2f}", *VIDEO, *AUDIO, str(corpo)])
    capa = cartao(ARTE / f"capa_{m['id']}.png", 3, TMP / f"capa_{m['id']}.mp4")
    nome = re.sub(r"[^A-Za-z0-9]+", "_", _sem_acento(m["titulo"].split(". ", 1)[-1])).strip("_")
    saida = SAIDA / f"APP-CIC_{m['id']}_{nome}.mp4"
    juntar([capa, corpo], saida)
    return saida


def juntar(partes, saida):
    lista = TMP / f"lista_{saida.stem}.txt"
    lista.write_text("".join(f"file '{Path(p).as_posix()}'\n" for p in partes), encoding="utf-8")
    _rodar([FFMPEG, "-y", "-f", "concat", "-safe", "0", "-i", str(lista), "-c", "copy", "-movflags", "+faststart", str(saida)])
    return saida


def _sem_acento(s):
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def completo(modulos_mp4):
    abertura = cartao(ARTE / "abertura.png", 4, TMP / "abertura.mp4")
    fim = cartao(ARTE / "encerramento.png", 4, TMP / "encerramento.mp4")
    return juntar([abertura, *modulos_mp4, fim], SAIDA / "APP-CIC_Treinamento_Completo.mp4")
