"""Treinamento em vídeo do APP-CIC (loja de demonstração).

Para cada módulo: narração pt-BR (edge-tts) + legenda (SRT) -> grava a tela com Playwright
-> junta vídeo, voz, legenda e título com ffmpeg. No fim, concatena o treinamento completo.

Uso: python gravar.py [id_modulo ...]   (sem argumentos grava todos)
"""
import asyncio
import json
import re
import subprocess
import sys
import time
from pathlib import Path

import edge_tts
import imageio_ffmpeg
from playwright.sync_api import sync_playwright

from montagem import completo, montar

sys.stdout.reconfigure(encoding="utf-8")
BASE = Path(__file__).parent
TMP = BASE / "work"
SAIDA = BASE / "videos"
TMP.mkdir(exist_ok=True)
SAIDA.mkdir(exist_ok=True)
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
URL = "http://127.0.0.1:8765/"
VOZ = "pt-BR-FranciscaNeural"
W, H = 1280, 800


# ---------------------------------------------------------------- ações na tela
def ligar_semantica(pg):
    pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
    pg.wait_for_timeout(800)


def botao(pg, nome):
    nome_re = re.compile("^" + re.escape(nome))
    return pg.get_by_role("button", name=nome_re).or_(pg.get_by_role("checkbox", name=nome_re)).first


def clicar(pg, nome, espera=1.5):
    el = botao(pg, nome)
    caixa = el.bounding_box()
    if caixa:  # move o mouse até lá (o cursor aparece no vídeo) e clica
        pg.mouse.move(caixa["x"] + caixa["width"] / 2, caixa["y"] + caixa["height"] / 2, steps=18)
        pg.wait_for_timeout(250)
    el.click()
    pg.wait_for_timeout(int(espera * 1000))


def rolar(pg, dy, vezes=1, espera=1.2, x=760, y=450):
    pg.mouse.move(x, y, steps=8)
    for _ in range(vezes):
        pg.mouse.wheel(0, dy)
        pg.wait_for_timeout(int(espera * 1000))


def digitar(pg, placeholder, texto, espera=0.6):
    campo = pg.locator(f"input[placeholder^='{placeholder}'], input[aria-label^='{placeholder}'], "
                       f"textarea[aria-label^='{placeholder}'], [role=textbox][aria-label^='{placeholder}']").first
    caixa = campo.bounding_box()
    if caixa:
        pg.mouse.move(caixa["x"] + 40, caixa["y"] + caixa["height"] / 2, steps=15)
    campo.click()
    pg.keyboard.type(texto, delay=55)
    pg.wait_for_timeout(int(espera * 1000))


def esperar(pg, s):
    pg.wait_for_timeout(int(s * 1000))


def ir(pg, aba):
    clicar(pg, aba, espera=1.8)


# Cada módulo: título, narração (frases curtas) e o que fazer na tela.
# Rótulos conferidos no código Flutter; seletores por papel ainda precisam de ensaio no navegador.
# Na DEMO, Pix começa sem chave: módulo 09 explica a confirmação, sem simular recebimento.
# Módulo 12 abre a seleção e cancela: não depende de consulta de mercado ou rede.
# Módulo 13 mostra o formulário sem enviar; módulo 14 explica o checklist oculto na DEMO.
MODULOS = [
    dict(id="00", titulo="Boas-vindas ao APP-CIC", aba="Visão Geral", narracao=[
        "Olá! Seja bem-vindo ao treinamento do APP-CIC.",
        "O APP-CIC junta, num lugar só, o cadastro de produtos, o estoque, o caixa, os custos e um assistente que responde dúvidas sobre a sua loja.",
        "Neste treinamento vamos usar o Mercadinho Bom Preço, uma loja de exemplo.",
        "Pode acompanhar com calma: cada vídeo mostra uma parte do aplicativo.",
        "No menu da esquerda ficam todas as áreas. Vamos começar!",
    ], acoes=lambda pg: (esperar(pg, 6), rolar(pg, 0, 1, 0.1, x=120, y=300), esperar(pg, 4),
                         [pg.mouse.move(120, 130 + 46 * i, steps=10) or esperar(pg, 0.5) for i in range(10)], esperar(pg, 3))),

    dict(id="01", titulo="1. Visão Geral", aba="Visão Geral", narracao=[
        "Esta é a Visão Geral: o resumo da sua loja.",
        "Nos cartões você vê quanto custou o seu estoque, quanto ele pode render e quais são os custos fixos do mês.",
        "Quando o lucro não cobre as despesas, aparece este alerta vermelho, explicando quanto falta.",
        "Mais abaixo, a Curva A B C mostra os produtos que mais trazem dinheiro.",
        "Toque em trinta dias para ver as vendas reais do último mês.",
        "Ao lado, o mix por categoria mostra onde está o seu dinheiro.",
    ], acoes=lambda pg: (esperar(pg, 3), pg.mouse.move(700, 140, steps=20), esperar(pg, 6),
                         pg.mouse.move(640, 300, steps=20), esperar(pg, 5), rolar(pg, 250, 1, 2),
                         clicar(pg, "30 dias", 4), rolar(pg, 300, 1, 2), pg.mouse.move(1100, 400, steps=20), esperar(pg, 4))),

    dict(id="02", titulo="2. Cadastrar produto pelo código de barras", aba="Leitor de códigos", narracao=[
        "Para cadastrar um produto, abra o Leitor de códigos.",
        "Toque em Abrir câmera e aponte para o código de barras. Se preferir, digite o código e toque em Consultar.",
        "Depois, preencha o nome, o lote, a validade, o preço de custo e o preço de venda.",
        "Se estiver contando o estoque, escolha substituir o saldo.",
        "Confira tudo e toque em Salvar no estoque. Pronto: o produto já pode ser vendido.",
    ], acoes=lambda pg: (esperar(pg, 3), pg.mouse.move(700, 200, steps=20), esperar(pg, 3),
                         digitar(pg, "Ex: 7891721201806", "7891000100103"), clicar(pg, "Consultar", 4),
                         rolar(pg, 250, 1, 3), rolar(pg, 250, 1, 3), esperar(pg, 4))),

    dict(id="03", titulo="3. Dar entrada pela nota fiscal (XML)", aba="Importador XML (NF-e)", narracao=[
        "Recebeu mercadoria com nota fiscal? Use o Importador X M L.",
        "Toque em Carregar arquivo e escolha o arquivo da nota que o fornecedor enviou. Ou cole o texto da nota.",
        "O aplicativo mostra cada item com custo, lote e validade, para você conferir.",
        "Escolha se quer atualizar o preço de venda e confirme a entrada.",
        "E pode ficar tranquilo: a mesma nota não entra duas vezes no estoque.",
    ], acoes=lambda pg: (esperar(pg, 4), pg.mouse.move(640, 220, steps=20), esperar(pg, 5),
                         pg.mouse.move(900, 300, steps=20), esperar(pg, 12))),

    dict(id="04", titulo="4. Estoque atual", aba="Estoque Atual", narracao=[
        "Em Estoque Atual você vê todos os seus produtos.",
        "Cada cartão mostra a quantidade, a validade, o custo e o preço de venda.",
        "Use os filtros para ver só o estoque baixo ou a validade crítica.",
        "Para corrigir um produto, toque em editar, ajuste e salve.",
        "Dica: mantenha o estoque mínimo certo, assim o aplicativo avisa antes de faltar.",
    ], acoes=lambda pg: (esperar(pg, 3), rolar(pg, 220, 2, 2.5), rolar(pg, -440, 1, 1.5),
                         clicar(pg, "Estoque Baixo", 4), clicar(pg, "Validade Crítica", 4), clicar(pg, "Todos", 3))),

    dict(id="05", titulo="5. Histórico de entradas e saídas", aba="Histórico & Movimentações", narracao=[
        "O Histórico mostra tudo o que entrou e saiu do estoque, com data e documento.",
        "Filtre por período, ou veja só as entradas ou só as saídas.",
        "Se precisar registrar uma perda ou um acerto, toque em Registrar Movimentação Manual e escolha o motivo certo.",
        "Assim você sempre sabe por que o saldo mudou.",
    ], acoes=lambda pg: (esperar(pg, 3), clicar(pg, "Últimos 7 dias", 3), clicar(pg, "Saídas", 3),
                         clicar(pg, "Entradas", 3), clicar(pg, "Todas", 2), rolar(pg, 250, 1, 3))),

    dict(id="06", titulo="6. Assistente: pergunte sobre a sua loja", aba="Inteligência IA", narracao=[
        "Agora a parte mais especial: o assistente da sua loja.",
        "Escreva a sua dúvida do jeito que você fala. Por exemplo: o que no meu estoque precisa de atenção agora?",
        "Ele responde com os números da sua loja: o que acabou, o que vai acabar e quanto comprar.",
        "Pode perguntar também: será que estou ganhando dinheiro?",
        "O assistente não inventa números. Se faltar algum dado, ele avisa.",
        "E ele só fala do seu negócio: estoque, vendas, custos e preços.",
    ], acoes=lambda pg: (esperar(pg, 2), rolar(pg, 400, 1, 1),
                         digitar(pg, "Pergunte sobre o seu negócio", "O que no meu estoque precisa de atenção agora?"),
                         clicar(pg, "Enviar", 9),
                         digitar(pg, "Pergunte sobre o seu negócio", "Será que estou ganhando dinheiro?"),
                         clicar(pg, "Enviar", 9))),

    dict(id="07", titulo="7. Custos e despesas", aba="Custos & Despesas", narracao=[
        "Em Custos e Despesas você registra o que mantém a loja funcionando.",
        "Custo fixo é o que você paga todo mês, como aluguel e energia.",
        "Despesa variável cresce com as vendas, como a taxa da maquininha e as sacolas.",
        "Com os custos cadastrados, o aplicativo calcula quanto você precisa vender para empatar.",
    ], acoes=lambda pg: (esperar(pg, 3), pg.mouse.move(500, 250, steps=20), esperar(pg, 4),
                         rolar(pg, 300, 1, 3), clicar(pg, "Fixos", 3), clicar(pg, "Variáveis", 3), clicar(pg, "Todas", 2))),

    dict(id="08", titulo="8. Central de alertas", aba="Central de Alertas", narracao=[
        "A Central de Alertas é a sua lista de lembretes.",
        "Ela avisa quando um produto acabou, está no mínimo ou perto de vencer.",
        "Resolva o que foi pedido e marque o alerta como lido.",
        "Assim todo mundo da loja sabe o que precisa ser feito primeiro.",
    ], acoes=lambda pg: (esperar(pg, 4), pg.mouse.move(700, 300, steps=20), esperar(pg, 5), rolar(pg, 200, 1, 4), esperar(pg, 3))),

    dict(id="09", titulo="9. Vender no caixa", aba="Frente de Caixa (PDV)", narracao=[
        "Na Frente de Caixa, bipe o código ou toque no produto e confira o carrinho.",
        "Para cobrar por Pix, primeiro cadastre a chave da loja em Conta.",
        "Copiar o código não confirma o pagamento. Confira o crédito no aplicativo do banco.",
        "Só então marque: Conferi no banco e recebi este PIX.",
        "No cartão, confirme a aprovação na máquina. No dinheiro, confira o troco.",
        "Finalize a venda para baixar o estoque e gerar um comprovante não fiscal. O app não emite cupom fiscal.",
    ], acoes=lambda pg: (esperar(pg, 4), pg.mouse.move(500, 300, steps=20), esperar(pg, 4),
                         rolar(pg, 450, 1, 4), rolar(pg, -450, 1, 4), esperar(pg, 4))),

    dict(id="10", titulo="10. Central do lojista", aba="Ajuda & Suporte", narracao=[
        "Ajuda e Suporte é a central do lojista.",
        "Aqui você encontra orientações sobre estoque, vendas, notas e alertas.",
        "Abra Como começo para rever os primeiros passos.",
        "Se precisar de atendimento, copie o e-mail e conte em qual tela estava e o que aconteceu.",
        "No menu, você também pode trocar o tema e aumentar a letra.",
    ], acoes=lambda pg: (esperar(pg, 3), rolar(pg, 500, 1, 3),
                         clicar(pg, "Como começo?", 3), clicar(pg, "Copiar e-mail", 3),
                         clicar(pg, "Tema", 2), clicar(pg, "Letra", 2))),

    dict(id="11", titulo="11. Logística reversa", aba="Logística reversa", narracao=[
        "Precisa retirar uma mercadoria por avaria, vencimento, recall ou devolução ao fornecedor?",
        "Em Logística reversa, escolha o produto, o motivo e o destino.",
        "Informe a quantidade e, se tiver, o documento ou protocolo.",
        "Confira tudo antes de tocar em Registrar saída reversa.",
        "A saída reduz o estoque e fica registrada no histórico. Ela não emite uma nota de devolução.",
    ], acoes=lambda pg: (esperar(pg, 4), rolar(pg, 300, 1, 4), rolar(pg, 250, 1, 4),
                         esperar(pg, 5))),

    dict(id="12", titulo="12. Pesquisa de mercado", aba="Inteligência IA", narracao=[
        "Em Análise de mercado e preço, toque em Analisar um produto.",
        "Escolha o item e use Consultar mercado quando estiver conectado.",
        "Com ofertas disponíveis, o app sugere aumentar, reduzir ou manter o preço.",
        "A sugestão respeita o custo e o piso de margem. Com dados insuficientes, pode pedir uma revisão.",
        "Confira as fontes e decida o preço. A sugestão não muda o cadastro sozinha.",
    ], acoes=lambda pg: (esperar(pg, 3), clicar(pg, "Analisar um produto", 3),
                         esperar(pg, 6), clicar(pg, "Cancelar", 2), esperar(pg, 5))),

    dict(id="13", titulo="13. Feedback semanal do teste de campo", aba="Inteligência IA", narracao=[
        "No teste de campo, conte toda semana como foi usar o app.",
        "Na sua conta, um aviso no início aparece enquanto a resposta da semana estiver pendente.",
        "Nesta demonstração, abrimos o formulário pela área de Inteligência IA.",
        "Dê uma nota, marque o que ajudou e escreva o que precisa melhorar.",
        "Depois toque em Enviar feedback. São cerca de dois minutos para orientar as próximas melhorias.",
    ], acoes=lambda pg: (esperar(pg, 3), clicar(pg, "Responder feedback semanal", 3),
                         rolar(pg, 250, 1, 4), esperar(pg, 5), clicar(pg, "Cancelar", 2))),

    # Checklist e aviso do início são ocultos em DEMO=true: não clicar em controles invisíveis.
    # Para filmar o checklist em ação, use uma conta de teste nova em build sem DEMO.
    dict(id="14", titulo="14. Primeiros passos da loja", aba="Visão Geral", narracao=[
        "Ao entrar com uma loja nova, o início mostra um checklist de preparação.",
        "Cadastre a chave Pix da loja, cadastre três produtos e faça a primeira venda.",
        "Toque no passo pendente para abrir a área correspondente.",
        "As marcas vêm dos dados da loja. Quando os três passos estiverem feitos, o cartão desaparece.",
        "O checklist não aparece nesta loja de demonstração. Use sua conta para acompanhar o progresso.",
    ], acoes=lambda pg: (esperar(pg, 5), rolar(pg, 200, 1, 4), esperar(pg, 8))),

]


# ---------------------------------------------------------------- narração
async def narrar(m):
    texto = " ".join(m["narracao"])
    com = edge_tts.Communicate(texto, VOZ, rate="-4%", boundary="SentenceBoundary")
    sub = edge_tts.SubMaker()
    with open(TMP / f"{m['id']}.mp3", "wb") as f:
        async for c in com.stream():
            if c["type"] == "audio":
                f.write(c["data"])
            elif c["type"] in ("WordBoundary", "SentenceBoundary"):
                sub.feed(c)
    (TMP / f"{m['id']}.srt").write_text(sub.get_srt(), encoding="utf-8")


def duracao(arq):
    r = subprocess.run([FFMPEG, "-i", str(arq)], capture_output=True, text=True, encoding="utf-8", errors="ignore")
    h, mi, s = re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr).groups()
    return int(h) * 3600 + int(mi) * 60 + float(s)


# ---------------------------------------------------------------- gravação
def gravar(m, pw):
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={"width": W, "height": H}, record_video_dir=str(TMP / "raw"),
                        record_video_size={"width": W, "height": H})
    t0 = time.time()
    pg = ctx.new_page()
    pg.goto(URL)
    pg.wait_for_timeout(5500)
    ligar_semantica(pg)
    if m["aba"] != "Visão Geral":
        botao(pg, m["aba"]).click()
    else:
        botao(pg, "Visão Geral").click()
    pg.mouse.move(W - 40, H - 40)
    pg.wait_for_timeout(1500)
    inicio = time.time() - t0
    m["acoes"](pg)
    pg.wait_for_timeout(1500)
    video = pg.video.path()
    ctx.close()
    b.close()
    return Path(video), inicio


def main():
    fonte = TMP / "segoeuib.ttf"
    if not fonte.exists():
        fonte.write_bytes(Path("C:/Windows/Fonts/segoeuib.ttf").read_bytes())
    pedidos = set(sys.argv[1:])
    escolhidos = [m for m in MODULOS if not pedidos or m["id"] in pedidos]
    feitos = json.loads((TMP / "feitos.json").read_text()) if (TMP / "feitos.json").exists() else {}
    for m in escolhidos:  # narração antes: o Playwright síncrono ocupa o event loop
        asyncio.run(narrar(m))
    with sync_playwright() as pw:
        for m in escolhidos:
            video, inicio = gravar(m, pw)
            saida = montar(m, video, inicio)
            feitos[m["id"]] = str(saida)
            print(f"ok {m['id']}  {saida.name}  ({duracao(saida):.0f}s)", flush=True)
    (TMP / "feitos.json").write_text(json.dumps(feitos, ensure_ascii=False, indent=1))
    if len(feitos) == len(MODULOS):
        c = completo([feitos[m["id"]] for m in MODULOS])
        print(f"ok completo  {c.name}  ({duracao(c) / 60:.1f} min)")

if __name__ == "__main__":
    main()
