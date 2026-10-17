"""Artes locais do APP-CIC. Execute: python gerar_arte.py (requer Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
REGULAR = Path('C:/Windows/Fonts/segoeui.ttf')
BOLD = Path('C:/Windows/Fonts/segoeuib.ttf')
BG, CARD, GOLD, GREEN = '#111111', '#1A1A1A', '#E5B53E', '#22C55E'
WHITE, MUTED, BORDER = '#FFFFFF', '#AEAEAE', '#303030'
SCALE = 2
TITLES = [
    'Boas-vindas ao APP-CIC', 'Visão Geral',
    'Cadastrar produto pelo código de barras',
    'Dar entrada pela nota fiscal (XML)', 'Estoque atual',
    'Histórico de entradas e saídas',
    'Assistente — pergunte sobre a sua loja', 'Custos e despesas',
    'Central de alertas', 'Vender no caixa', 'Central do lojista',
    'Logística reversa', 'Pesquisa de mercado',
    'Feedback semanal do teste de campo', 'Primeiros passos da loja',
]


class Canvas:
    def __init__(self, width=1280, height=800):
        self.im = Image.new('RGB', (width * SCALE, height * SCALE), BG)
        self.d = ImageDraw.Draw(self.im)
        self.width, self.height = width, height

    def font(self, size, bold=False):
        return ImageFont.truetype(str(BOLD if bold else REGULAR), round(size * SCALE))

    def box(self, bounds, fill=CARD, radius=24, outline=None):
        self.d.rounded_rectangle(tuple(round(v * SCALE) for v in bounds),
                                 radius=radius * SCALE, fill=fill,
                                 outline=outline, width=2 * SCALE)

    def text(self, xy, text, size=24, color=WHITE, bold=False):
        self.d.text(tuple(round(v * SCALE) for v in xy), text,
                    font=self.font(size, bold), fill=color, anchor='lt')

    def lines(self, text, size, width, bold=True):
        lines, line = [], ''
        for word in text.split():
            candidate = f'{line} {word}'.strip()
            if self.d.textlength(candidate, font=self.font(size, bold)) > width * SCALE:
                if not line:
                    raise ValueError(f'Palavra não cabe: {word}')
                lines.append(line)
                line = word
            else:
                line = candidate
        return lines + [line]

    def paragraph(self, xy, text, size, width, color=WHITE, bold=True, gap=1.23):
        x, y = xy
        lines = self.lines(text, size, width, bold)
        for i, line in enumerate(lines):
            self.text((x, y + i * size * gap), line, size, color, bold)
        return y + len(lines) * size * gap

    def brand(self, x=64, y=52):
        self.box((x, y, x + 46, y + 46), GOLD, 12)
        for offset, width in [(11, 3), (17, 2), (22, 4), (29, 2), (34, 2)]:
            self.box((x + offset, y + 11, x + offset + width, y + 35), BG, 0)
        self.text((x + 60, y + 6), 'APP-CIC', 30, WHITE, True)

    def footer(self, label='TREINAMENTO PARA O LOJISTA'):
        y = self.height - 64
        self.box((64, y + 6, 72, y + 14), GREEN, 4)
        self.text((84, y), label, 16, MUTED)

    def save(self, filename):
        self.im.resize((self.width, self.height), Image.Resampling.LANCZOS).save(OUT / filename)


def cover(index, title):
    c = Canvas()
    c.brand()
    c.text((974, 67), 'GUIA PASSO A PASSO', 16, MUTED)
    c.box((64, 156, 1216, 668), outline=BORDER, radius=32)
    c.box((96, 192, 104, 628), GOLD, 4)
    c.text((140, 224), f'{index:02d}', 174, GOLD, True)
    c.text((144, 444), 'MÓDULO', 18, MUTED)
    c.text((430, 224), 'SEU MERCADINHO, MAIS ORGANIZADO', 17, GOLD)
    lines = c.lines(title, 53, 726)
    y = 329 if len(lines) <= 2 else 300
    end = c.paragraph((430, y), title, 53, 726)
    assert end < 610, (index, end)
    c.footer()
    c.text((1060, 736), f'{index + 1:02d} / {len(TITLES)}', 18, MUTED)
    c.save(f'capa_{index:02d}.png')


def opening():
    c = Canvas()
    c.brand()
    c.box((64, 156, 1216, 668), radius=32, outline=BORDER)
    c.text((112, 208), 'BEM-VINDO À SUA PRÓXIMA ETAPA', 18, GOLD)
    c.text((108, 263), 'APP-CIC', 100, WHITE, True)
    c.text((112, 402), 'Treinamento para o lojista', 48, WHITE, True)
    c.text((112, 494), 'Mercadinho Bom Preço — loja de exemplo', 29, MUTED)
    c.box((112, 572, 444, 620), '#203326', 14)
    c.text((132, 584), 'Um passo de cada vez.', 23, GREEN)
    c.footer('APRENDA NO SEU RITMO')
    c.save('abertura.png')


def closing():
    c = Canvas()
    c.brand()
    c.box((64, 156, 1216, 668), radius=32, outline=BORDER)
    c.box((112, 207, 180, 275), '#203326', 20)
    c.d.line([(130*SCALE, 241*SCALE), (142*SCALE, 252*SCALE),
              (162*SCALE, 229*SCALE)], fill=GREEN, width=5*SCALE)
    c.paragraph((112, 321), 'Bom trabalho e boas vendas!', 67, 900)
    c.text((112, 542), 'APP-CIC — Projeto de Extensão Senac', 31, GOLD)
    c.footer('OBRIGADO POR APRENDER COM A GENTE')
    c.save('encerramento.png')


def social():
    c = Canvas(1080, 1350)
    c.brand(64, 64)
    c.text((64, 168), 'TECNOLOGIA A SERVIÇO DO PEQUENO COMÉRCIO', 18, GOLD)
    c.box((56, 230, 1024, 1122), radius=36, outline=BORDER)
    c.box((96, 278, 168, 285), GOLD, 3)
    c.paragraph((96, 325), 'Estoque, caixa e um assistente que não inventa números',
                70, 865)
    c.paragraph((96, 792), 'Respostas conferidas com os dados da loja. Quando há inconsistências detectadas, o app mostra os cálculos disponíveis.',
                26, 840, MUTED, False)
    for x, label in [(96, 'ESTOQUE'), (364, 'CAIXA'), (632, 'ASSISTENTE')]:
        c.box((x, 1000, x + 248, 1062), BG, 16, BORDER)
        c.text((x + 24, 1020), label, 20, GOLD, True)
    c.box((64, 1170, 1016, 1258), '#203326', 24)
    c.text((96, 1199), 'Projeto de Extensão Senac', 30, WHITE, True)
    c.footer('APRENDIZADO QUE SE TRANSFORMA EM SOLUÇÃO')
    c.save('capa_post.png')


def main():
    if not REGULAR.is_file() or not BOLD.is_file():
        raise FileNotFoundError('Instale as fontes Segoe UI e Segoe UI Bold indicadas no script.')
    OUT.mkdir(parents=True, exist_ok=True)
    opening()
    closing()
    for i, title in enumerate(TITLES):
        cover(i, title)
    social()
    print(f'{len(TITLES) + 3} artes PNG geradas em', OUT)


if __name__ == '__main__':
    main()
