# Como regravar os vídeos de treinamento

Os vídeos usam a **loja de demonstração** (Mercadinho Bom Preço), sem login e sem dados reais.

1. Gere o app de demonstração e sirva localmente:
   ```bash
   flutter build web --release --dart-define=DEMO=true
   python -m http.server 8765 --bind 127.0.0.1 --directory build/web
   ```
2. Instale as ferramentas (uma vez): `pip install playwright edge-tts imageio-ffmpeg` e `playwright install chromium`.
3. Copie a pasta `../arte` para `arte/` ao lado destes scripts (as capas vêm de `gerar_arte.py`).
4. Grave:
   - `python gravar.py` — os 11 módulos e o `APP-CIC_Treinamento_Completo.mp4` (voz pt-BR Francisca, legenda e capa por módulo).
   - `python gravar.py 06` — só um módulo (ex.: o do assistente).
   - `python publicacao.py` — vídeo vertical de divulgação (1080×1920, voz Antonio).
   - `python prints.py` — os prints do README em `docs/prints/`.
   - `python quadros.py video.mp4 5 20` — tira quadros para conferir um vídeo.

O roteiro (o que cada módulo mostra e fala) está em `../roteiro.md`; o texto narrado fica na lista `MODULOS` de `gravar.py`.
