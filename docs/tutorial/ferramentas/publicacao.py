"""Vídeo vertical de divulgação (1080x1920): app no layout de celular + narração + legenda grande."""
import asyncio
import re
import subprocess
import sys
import time
from pathlib import Path

import edge_tts
from playwright.sync_api import sync_playwright

from montagem import AUDIO, FFMPEG, TMP, VIDEO, ARTE, SAIDA, duracao, juntar

sys.stdout.reconfigure(encoding="utf-8")
URL = "http://127.0.0.1:8765/"
FALA = [
    "Conheça o APP-CIC, projeto de extensão do Senac para o pequeno comércio.",
    "Num lugar só: estoque com validade, frente de caixa, custos e alertas.",
    "Bipe o código de barras e o produto já está cadastrado.",
    "E o diferencial: um assistente que responde sobre a sua loja.",
    "Pergunte o que precisa de atenção, e ele mostra o que acabou e quanto comprar.",
    "Tudo calculado com os dados da loja. Ele não inventa números.",
    "APP-CIC: pergunte, entenda e decida com mais clareza.",
]


async def narrar():
    com = edge_tts.Communicate(" ".join(FALA), "pt-BR-AntonioNeural", rate="+2%", boundary="SentenceBoundary")
    sub = edge_tts.SubMaker()
    with open(TMP / "pub.mp3", "wb") as f:
        async for c in com.stream():
            if c["type"] == "audio":
                f.write(c["data"])
            elif c["type"] in ("WordBoundary", "SentenceBoundary"):
                sub.feed(c)
    (TMP / "pub.srt").write_text(sub.get_srt(), encoding="utf-8")


def gravar():
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        ctx = b.new_context(viewport={"width": 540, "height": 960}, device_scale_factor=2, is_mobile=True, has_touch=True,
                            record_video_dir=str(TMP / "raw_pub"), record_video_size={"width": 540, "height": 960})
        t0 = time.time()
        pg = ctx.new_page()
        pg.goto(URL)
        pg.wait_for_timeout(6000)
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
        pg.wait_for_timeout(800)
        inicio = time.time() - t0

        def toque(nome, espera):
            r = re.compile("^" + re.escape(nome))
            pg.get_by_role("button", name=r).or_(pg.get_by_role("tab", name=r)).first.click()
            pg.wait_for_timeout(int(espera * 1000))

        def rolar(dy, espera):
            pg.mouse.move(270, 500)
            pg.mouse.wheel(0, dy)
            pg.wait_for_timeout(int(espera * 1000))

        pg.wait_for_timeout(3000)
        rolar(500, 2.5)
        rolar(500, 2.5)
        toque("Vender", 3)
        rolar(400, 2)
        toque("Estoque", 4)
        toque("Assistente", 1.5)
        campo = pg.locator("input[aria-label^='Pergunte'], textarea[aria-label^='Pergunte'], [role=textbox][aria-label^='Pergunte']").first
        campo.click()
        pg.keyboard.type("O que precisa de atenção agora?", delay=60)
        toque("Enviar", 9)
        video = pg.video.path()
        ctx.close()
        b.close()
        return Path(video), inicio


def montar(video, inicio):
    dur = max(duracao(TMP / "pub.mp3") + 1.0, duracao(video) - inicio)
    estilo = ("FontName=Segoe UI Black,FontSize=15,PrimaryColour=&H00FFFFFF,OutlineColour=&H50111111,"
              "BorderStyle=3,Outline=6,Shadow=0,MarginV=70,Alignment=2")
    corpo = TMP / "pub_corpo.mp4"
    filtro = (f"[0:v]tpad=stop_mode=clone:stop_duration=30,scale=1080:1920:flags=lanczos,setsar=1,"
              f"fade=t=in:st=0:d=0.4,fade=t=out:st={dur - 0.5:.2f}:d=0.5,"
              f"subtitles=pub.srt:force_style='{estilo}'[v]")
    r = subprocess.run([FFMPEG, "-y", "-ss", f"{inicio:.2f}", "-i", str(video), "-i", "pub.mp3", "-filter_complex", filtro,
                        "-map", "[v]", "-map", "1:a", "-af", "apad", "-t", f"{dur:.2f}", *VIDEO, *AUDIO, str(corpo)],
                       cwd=TMP, capture_output=True, text=True, encoding="utf-8", errors="ignore")
    if r.returncode:
        raise RuntimeError(r.stderr[-1200:])
    # Capa do post (1080x1350) centralizada em 1080x1920 no fim, 3 s.
    capa = TMP / "pub_capa.mp4"
    r = subprocess.run([FFMPEG, "-y", "-loop", "1", "-t", "3", "-i", str(ARTE / "capa_post.png"), "-f", "lavfi", "-t", "3",
                        "-i", "anullsrc=r=48000:cl=stereo", "-filter_complex",
                        "[0:v]scale=1080:1350,pad=1080:1920:0:285:color=0x111111,fps=30,format=yuv420p,fade=t=in:st=0:d=0.4[v]",
                        "-map", "[v]", "-map", "1:a", "-t", "3", *VIDEO, *AUDIO, str(capa)],
                       cwd=TMP, capture_output=True, text=True, encoding="utf-8", errors="ignore")
    if r.returncode:
        raise RuntimeError(r.stderr[-1200:])
    return juntar([corpo, capa], SAIDA / "APP-CIC_Divulgacao_Vertical.mp4")


if __name__ == "__main__":
    asyncio.run(narrar())
    v, i = gravar()
    s = montar(v, i)
    print(f"ok {s.name} ({duracao(s):.0f}s)")
