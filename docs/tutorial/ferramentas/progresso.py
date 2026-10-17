"""Progresso local por módulo; nenhuma chamada de rede."""
import hashlib
import json
from pathlib import Path


def assinatura(arquivos):
    digest = hashlib.sha256()
    for arquivo in arquivos:
        caminho = Path(arquivo)
        if not caminho.is_file():
            raise FileNotFoundError(caminho)
        digest.update(caminho.name.encode('utf-8'))
        digest.update(caminho.read_bytes())
    return digest.hexdigest()


def carregar(caminho):
    if not Path(caminho).exists():
        return {}
    dados = json.loads(Path(caminho).read_text(encoding='utf-8'))
    if not isinstance(dados, dict):
        raise ValueError('O progresso deve ser um objeto JSON.')
    return dados


def salvar(caminho, dados):
    caminho = Path(caminho)
    temporario = caminho.with_suffix('.tmp')
    temporario.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding='utf-8')
    temporario.replace(caminho)


def pronto(registro, versao, *campos):
    if registro.get('assinatura') != versao:
        return False
    return all(registro.get(campo) and Path(registro[campo]).is_file()
               and Path(registro[campo]).stat().st_size > 0 for campo in campos)
