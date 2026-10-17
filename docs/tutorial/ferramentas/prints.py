"""Prints do README (loja de demonstração) direto na pasta docs/prints do clone do Codex."""
import re
from pathlib import Path

from playwright.sync_api import sync_playwright

DESTINO = str(Path(__file__).resolve().parents[2] / "prints") + "/"
URL = "http://127.0.0.1:8765/"


def botao(pg, nome):
    r = re.compile("^" + re.escape(nome))
    return pg.get_by_role("button", name=r).or_(pg.get_by_role("checkbox", name=r)).first


with sync_playwright() as pw:
    b = pw.chromium.launch()
    pg = b.new_page(viewport={"width": 1280, "height": 800})
    pg.goto(URL)
    pg.wait_for_timeout(6000)
    pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
    pg.wait_for_timeout(800)
    pg.mouse.move(1270, 790)
    pg.screenshot(path=DESTINO + "inicio.png")
    for aba, arq in [("Leitor GS1 & Cadastro", "leitor"), ("Estoque Atual", "estoque"), ("Frente de Caixa (PDV)", "vender")]:
        botao(pg, aba).click()
        pg.wait_for_timeout(1800)
        pg.mouse.move(1270, 790)
        pg.screenshot(path=DESTINO + arq + ".png")
    botao(pg, "Inteligência IA").click()
    pg.wait_for_timeout(1500)
    campo = pg.locator("input[aria-label^='Pergunte'], textarea[aria-label^='Pergunte'], [role=textbox][aria-label^='Pergunte']").first
    campo.click()
    pg.keyboard.type("O que no meu estoque precisa de atenção agora?")
    botao(pg, "Enviar").click()
    pg.wait_for_timeout(2500)
    pg.mouse.move(1270, 790)
    pg.screenshot(path=DESTINO + "assistente.png")
    b.close()
print("ok")
