"""Transforma o CSV do relatório do piloto em ações para revisão humana. Não envia mensagens."""
import argparse
import csv
import sys


def acao(loja):
    produtos = int(loja['produtos'])
    vendas = int(loja['vendas_total'])
    recentes = int(loja['vendas_7d'])
    dias = int(loja['dias_cadastro'])
    nota = int(loja['nota']) if loja.get('nota', '').strip() else None
    if min(produtos, vendas, recentes, dias) < 0 or (nota is not None and not 1 <= nota <= 5):
        raise ValueError('Contagens ou nota inválidas.')
    if recentes > vendas:
        raise ValueError('Vendas recentes não podem superar o total.')
    feedback = loja['feedback_semana'].strip().lower()
    if feedback not in ('true', 'false', 't', 'f'):
        raise ValueError('feedback_semana deve ser true/false ou t/f.')
    interesse = loja['interesse_site']
    if interesse not in ('nao_agora', 'quero_conhecer', 'quero_orcamento'):
        raise ValueError('Interesse em site desconhecido.')
    if nota is not None and nota <= 2:
        return 1, 'Resolver dificuldade relatada antes de apresentar oferta'
    if interesse == 'quero_orcamento':
        return 2, 'Preparar proposta do site solicitado, com escopo e preço'
    if interesse == 'quero_conhecer':
        return 3, 'Separar demonstração do site e confirmar o interesse'
    if produtos < 3:
        return 4, 'Ajudar a cadastrar três produtos distintos'
    if vendas == 0:
        return 5, 'Orientar a primeira venda e conferir o pagamento manual'
    if dias >= 7 and recentes == 0:
        return 6, 'Investigar por que a loja deixou de registrar vendas'
    if feedback in ('false', 'f'):
        return 7, 'Conferir se o lembrete de feedback foi visto; evitar contato repetido'
    return 8, 'Acompanhar uso; não há oferta solicitada'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', help='Exportação de supabase/relatorio_piloto_leadforge.sql')
    args = parser.parse_args()
    filas = []
    with open(args.csv, newline='', encoding='utf-8-sig') as arquivo:
        for numero, loja in enumerate(csv.DictReader(arquivo), 2):
            try:
                slug = loja['slug']
                if not slug or len(slug) > 80 or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in slug):
                    raise ValueError('Slug inválido.')
                prioridade, tarefa = acao(loja)
                filas.append((prioridade, slug, tarefa))
            except (KeyError, TypeError, ValueError) as erro:
                parser.error(f'Linha {numero}: {erro}')
    saida = csv.writer(sys.stdout)
    saida.writerow(['prioridade', 'slug', 'proxima_acao'])
    saida.writerows(sorted(filas))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
