import tempfile
import unittest
from pathlib import Path

from progresso import assinatura, carregar, pronto, salvar


class ProgressoTest(unittest.TestCase):
    def test_retomada_preserva_modulo_anterior_apos_falha_no_seguinte(self):
        with tempfile.TemporaryDirectory() as pasta:
            base = Path(pasta)
            video = base / '01.mp4'
            video.write_bytes(b'video-de-teste')
            manifesto = base / 'progresso.json'
            salvar(manifesto, {'01': {'assinatura': 'atual', 'saida': str(video)}})
            recuperado = carregar(manifesto)
            self.assertTrue(pronto(recuperado['01'], 'atual', 'saida'))
            self.assertFalse(pronto(recuperado.get('02', {}), 'atual', 'saida'))
            self.assertFalse(pronto(recuperado['01'], 'alterada', 'saida'))
            video.unlink()
            self.assertFalse(pronto(recuperado['01'], 'atual', 'saida'))

    def test_etapas_parciais_e_arquivo_vazio_nao_contam_como_concluidas(self):
        with tempfile.TemporaryDirectory() as pasta:
            audio = Path(pasta) / 'voz.mp3'
            legenda = Path(pasta) / 'voz.srt'
            audio.write_bytes(b'voz')
            legenda.touch()
            registro = {'assinatura': 'v1', 'audio': str(audio), 'legenda': str(legenda)}
            self.assertFalse(pronto(registro, 'v1', 'audio', 'legenda'))
            legenda.write_text('Legenda', encoding='utf-8')
            self.assertTrue(pronto(registro, 'v1', 'audio', 'legenda'))
            self.assertFalse(pronto(registro, 'v1', 'video'))

    def test_assinatura_muda_quando_app_ou_roteiro_muda(self):
        with tempfile.TemporaryDirectory() as pasta:
            app = Path(pasta) / 'main.dart.js'
            roteiro = Path(pasta) / 'gravar.py'
            app.write_text('app v1', encoding='utf-8')
            roteiro.write_text('roteiro v1', encoding='utf-8')
            original = assinatura([app, roteiro])
            app.write_text('app v2', encoding='utf-8')
            self.assertNotEqual(original, assinatura([app, roteiro]))
            atual = assinatura([app, roteiro])
            roteiro.write_text('roteiro v2', encoding='utf-8')
            self.assertNotEqual(atual, assinatura([app, roteiro]))


if __name__ == '__main__':
    unittest.main()
