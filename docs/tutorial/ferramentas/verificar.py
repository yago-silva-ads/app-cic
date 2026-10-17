"""Pré-checagem offline: python verificar.py. Não grava, não instala e não envia nada."""
import ast
import importlib.util
from pathlib import Path
import sys

BASE = Path(__file__).resolve().parent


def verificar():
    pendencias = []
    fonte = ast.parse((BASE / 'gravar.py').read_text(encoding='utf-8'))
    lista = next(n.value for n in fonte.body if isinstance(n, ast.Assign)
                 and any(isinstance(a, ast.Name) and a.id == 'MODULOS' for a in n.targets))
    modulos = [{k.arg: ast.literal_eval(k.value) for k in n.keywords if k.arg != 'acoes'}
               for n in lista.elts]
    ids = [m['id'] for m in modulos]
    if len(ids) != len(set(ids)):
        pendencias.append('Há IDs de módulo repetidos.')
    for dependencia in ['playwright', 'edge_tts', 'imageio_ffmpeg', 'PIL']:
        if importlib.util.find_spec(dependencia) is None:
            pendencias.append(f'Dependência ausente: {dependencia}')
    arte = BASE.parent / 'arte'
    for nome in ['abertura.png', 'encerramento.png', *(f'capa_{i}.png' for i in ids)]:
        if not (arte / nome).is_file():
            pendencias.append(f'Arte ausente: {nome}')
    for nome in ['montagem.py', 'progresso.py']:
        if not (BASE / nome).is_file():
            pendencias.append(f'Ferramenta ausente: {nome}')
    app = BASE.parents[2] / 'build' / 'web'
    if not (app / 'main.dart.js').is_file():
        pendencias.append('Gere o build web com --dart-define=DEMO=true antes de gravar.')
    print(f'{len(modulos)} módulos: {", ".join(ids)}')
    print('DEMO: checklist oculto; feedback pela Inteligência IA; Pix sem confirmação simulada.')
    print('A narração usa edge-tts pela rede. Esta pré-checagem é offline.')
    print('Browser Chromium e servidor local precisam de ensaio antes da gravação completa.')
    for item in pendencias:
        print(f'PENDENTE: {item}')
    if not pendencias:
        print('Pré-requisitos locais presentes. Falta o ensaio no navegador.')
    return 1 if pendencias else 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(verificar())
