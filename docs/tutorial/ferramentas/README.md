# Produção dos vídeos por etapas

1. Execute `python ../arte/gerar_arte.py`: gera as 15 capas, abertura, encerramento e arte de divulgação. Requer Pillow e fontes Segoe UI do Windows.
2. Execute `python verificar.py`: confere módulos, dependências, capas e build sem instalar nada ou acessar a rede.
3. Gere o app: `flutter build web --release --dart-define=DEMO=true`. Na raiz do projeto, sirva com `python -m http.server 8765 --bind 127.0.0.1 --directory build/web`.
4. Prepare as dependências no ambiente de gravação: `python -m pip install playwright edge-tts imageio-ffmpeg` e `python -m playwright install chromium`.
5. Ensaie um módulo curto: `python gravar.py 10`. Confira vídeo, áudio, legenda, cursor e rótulos antes de gravar o restante.
6. Grave os novos módulos: `python gravar.py 11 12 13 14 --retomar`.
7. Grave o conjunto completo: `python gravar.py --retomar`. Ao completar os 15 módulos da mesma versão, o treinamento completo é montado automaticamente.

Execute os comandos Python desta pasta, exceto quando indicado. As capas são lidas diretamente de `../arte/`; não é necessário copiar imagens.

O gravador salva `work/progresso.json` após cada narração, captura e montagem. Com `--retomar`, reaproveita etapas da mesma versão que têm arquivos presentes e não vazios. Se a montagem falhar, a captura já salva pode ser reaproveitada. Se o app compilado, o gravador, a montagem ou a capa mudar, os resultados afetados não são tratados como atuais. Para forçar a regravação, omita `--retomar`. Não rode duas gravações simultâneas nesta pasta.

`work/` e `videos/` ficam fora do Git. Guarde os MP4 finais em `APP-CIC_VIDEOS` depois da revisão. `feitos.json` lista os resultados atuais; não mistura automaticamente vídeos antigos com módulos desta versão. Teste a retomada com `python -m unittest test_progresso.py`.

A pré-checagem é offline, mas a narração edge-tts precisa de rede. Playwright também precisa do Chromium instalado. A confirmação dos papéis acessíveis exige ensaio no navegador: a pré-checagem não comprova que um clique funciona.

## O que a DEMO permite mostrar

- Feedback: abrir por **Inteligência IA → Responder feedback semanal** e cancelar sem enviar.
- Mercado: abrir **Analisar um produto** e cancelar. Um resultado com ofertas reais exige consulta separada e conexão disponível.
- Pix: explicar a chave e a confirmação manual; não simular crédito bancário.
- Primeiros passos: explicação narrada. O checklist e o aviso semanal do início estão ocultos na DEMO. Para uma tomada real, use uma conta de teste nova, sem dados de comerciantes.

Não apresente essas tomadas explicativas como validação de pagamento, emissão fiscal ou integração oficial com a GS1. O roteiro completo está em [roteiro.md](../roteiro.md).
