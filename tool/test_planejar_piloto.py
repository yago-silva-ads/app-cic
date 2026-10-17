import unittest

from planejar_piloto import acao


class PlanejarPilotoTest(unittest.TestCase):
    def loja(self, **campos):
        return dict(produtos='3', vendas_total='10', vendas_7d='2', dias_cadastro='8',
                    nota='', feedback_semana='true', interesse_site='nao_agora') | campos

    def test_dificuldade_tem_prioridade_sobre_venda(self):
        self.assertEqual(acao(self.loja(nota='1', interesse_site='quero_orcamento'))[0], 1)

    def test_oferta_so_quando_interesse_foi_registrado(self):
        self.assertEqual(acao(self.loja(interesse_site='quero_orcamento'))[0], 2)
        self.assertEqual(acao(self.loja(interesse_site='quero_conhecer'))[0], 3)
        self.assertEqual(acao(self.loja())[0], 8)

    def test_ativacao_uso_e_feedback(self):
        self.assertEqual(acao(self.loja(produtos='2'))[0], 4)
        self.assertEqual(acao(self.loja(vendas_total='0', vendas_7d='0'))[0], 5)
        self.assertEqual(acao(self.loja(vendas_7d='0'))[0], 6)
        self.assertEqual(acao(self.loja(feedback_semana='f'))[0], 7)

    def test_dado_invalido_nao_vira_recomendacao(self):
        for campos in [dict(nota='6'), dict(produtos='-1'), dict(vendas_7d='11'),
                       dict(feedback_semana='talvez'), dict(interesse_site='comprou')]:
            with self.assertRaises(ValueError):
                acao(self.loja(**campos))


if __name__ == '__main__':
    unittest.main()
