// Leitor de código de barras para a versão Web (iPhone/Safari e computador).
//
// Por que existe: o leitor padrão abria a câmera em 640x480 e sem controle de
// foco. No iPhone isso deixa códigos pequenos ilegíveis. Aqui:
//  - pedimos resolução alta (dá para ler de mais longe, onde a imagem é nítida);
//  - ligamos foco contínuo e zoom quando o aparelho permite;
//  - oferecemos "Foto": abre a câmera NATIVA (macro/autofoco) e lê da foto;
//  - a lanterna só aparece se o navegador realmente suportar (Safari não suporta).
// API: window.cicScanner.abrir() -> Promise<string|null> (null = cancelado/digitar)
(function () {
  'use strict';

  function formatos() {
    var F = ZXing.BarcodeFormat;
    return [F.EAN_13, F.EAN_8, F.UPC_A, F.UPC_E, F.CODE_128, F.CODE_39, F.ITF, F.QR_CODE, F.DATA_MATRIX];
  }

  function novoLeitor() {
    var hints = new Map();
    hints.set(ZXing.DecodeHintType.POSSIBLE_FORMATS, formatos());
    hints.set(ZXing.DecodeHintType.TRY_HARDER, true);
    return new ZXing.BrowserMultiFormatReader(hints, 120);
  }

  function gtinValido(c) {
    if (!/^\d+$/.test(c) || [8, 12, 13, 14].indexOf(c.length) < 0) return true; // não é GTIN: aceita
    var soma = 0;
    for (var i = 0; i < c.length - 1; i++) {
      var pos = c.length - 1 - i;
      soma += parseInt(c[i], 10) * (pos % 2 === 1 ? 3 : 1);
    }
    return (10 - (soma % 10)) % 10 === parseInt(c[c.length - 1], 10);
  }

  // Lê código de uma foto. (decodeFromImageUrl do ZXing 0.19 falha mesmo com
  // imagem perfeita; desenhar num canvas e decodificar direto funciona.)
  // Tenta várias escalas, rotação de 90° e dois binarizadores: fotos de
  // celular são enormes, às vezes tortas e com luz irregular.
  function decodificarFoto(arquivo) {
    var hints = new Map();
    hints.set(ZXing.DecodeHintType.POSSIBLE_FORMATS, formatos());
    hints.set(ZXing.DecodeHintType.TRY_HARDER, true);
    var url = URL.createObjectURL(arquivo);
    var img = new Image();
    img.src = url;
    return img.decode().then(function () {
      var larguras = [1600, 1000, 2400, 700];
      var rotacoes = [0, 90];
      var binarizadores = [
        function (s) { return new ZXing.HybridBinarizer(s); },
        function (s) { return new ZXing.GlobalHistogramBinarizer(s); }
      ];
      for (var r = 0; r < rotacoes.length; r++) {
        for (var l = 0; l < larguras.length; l++) {
          var esc = Math.min(1, larguras[l] / Math.max(img.naturalWidth, img.naturalHeight));
          var w = Math.max(1, Math.round(img.naturalWidth * esc));
          var h = Math.max(1, Math.round(img.naturalHeight * esc));
          var c = document.createElement('canvas');
          var ctx = c.getContext('2d');
          if (rotacoes[r] === 90) {
            c.width = h; c.height = w;
            ctx.translate(h, 0); ctx.rotate(Math.PI / 2);
          } else {
            c.width = w; c.height = h;
          }
          ctx.drawImage(img, 0, 0, w, h);
          for (var b = 0; b < binarizadores.length; b++) {
            try {
              var fonte = new ZXing.HTMLCanvasElementLuminanceSource(c);
              var res = new ZXing.MultiFormatReader().decode(new ZXing.BinaryBitmap(binarizadores[b](fonte)), hints);
              if (res && res.getText()) { URL.revokeObjectURL(url); return res.getText(); }
            } catch (e) { /* tenta a próxima combinação */ }
          }
        }
      }
      URL.revokeObjectURL(url);
      return null;
    }).catch(function () { URL.revokeObjectURL(url); return null; });
  }

  function el(tag, estilo, texto) {
    var e = document.createElement(tag);
    if (estilo) e.setAttribute('style', estilo);
    if (texto) e.textContent = texto;
    return e;
  }

  var BTN = 'border:0;border-radius:14px;padding:14px 16px;font:700 15px -apple-system,system-ui,sans-serif;cursor:pointer;';

  function abrir() {
    return new Promise(function (resolve) {
      if (typeof ZXing === 'undefined') { resolve(null); return; }
      var leitor = novoLeitor();
      var encerrado = false;
      var stream = null;

      var raiz = el('div', 'position:fixed;inset:0;z-index:2147483647;background:#000;display:flex;flex-direction:column;font-family:-apple-system,system-ui,sans-serif;');
      var topo = el('div', 'display:flex;align-items:center;justify-content:space-between;padding:calc(env(safe-area-inset-top) + 10px) 14px 10px;color:#fff;');
      topo.appendChild(el('div', 'font:800 17px -apple-system,system-ui,sans-serif;', 'Bipar código de barras'));
      var fechar = el('button', BTN + 'background:#222;color:#fff;padding:10px 14px;', 'Fechar');
      topo.appendChild(fechar);

      var area = el('div', 'position:relative;flex:1;overflow:hidden;');
      var video = el('video', 'width:100%;height:100%;object-fit:cover;');
      video.setAttribute('playsinline', ''); video.setAttribute('muted', ''); video.muted = true;
      var mira = el('div', 'position:absolute;left:8%;right:8%;top:38%;height:24%;border:3px solid #D4A843;border-radius:16px;box-shadow:0 0 0 9999px rgba(0,0,0,.35);pointer-events:none;');
      var dica = el('div', 'position:absolute;left:12px;right:12px;bottom:12px;text-align:center;color:#fff;font:600 15px -apple-system,system-ui,sans-serif;text-shadow:0 1px 3px #000;',
        'Segure a uns 15 a 20 cm do código. Se borrar, afaste e use o zoom.');
      area.appendChild(video); area.appendChild(mira); area.appendChild(dica);

      var barra = el('div', 'display:flex;gap:10px;flex-wrap:wrap;justify-content:center;padding:12px 12px calc(env(safe-area-inset-bottom) + 14px);background:#111;');
      var bZoom = el('button', BTN + 'background:#222;color:#fff;display:none;', 'Zoom 1x');
      var bLuz = el('button', BTN + 'background:#222;color:#fff;display:none;', 'Lanterna');
      var bFoto = el('button', BTN + 'background:#D4A843;color:#000;', '📷 Foto do código');
      var bDigitar = el('button', BTN + 'background:#222;color:#fff;', 'Digitar');
      barra.appendChild(bZoom); barra.appendChild(bLuz); barra.appendChild(bFoto); barra.appendChild(bDigitar);

      var arquivo = el('input', 'display:none;');
      arquivo.type = 'file'; arquivo.accept = 'image/*'; arquivo.setAttribute('capture', 'environment');

      raiz.appendChild(topo); raiz.appendChild(area); raiz.appendChild(barra); raiz.appendChild(arquivo);
      document.body.appendChild(raiz);

      function terminar(valor) {
        if (encerrado) return;
        encerrado = true;
        try { leitor.reset(); } catch (e) {}
        try { if (stream) stream.getTracks().forEach(function (t) { t.stop(); }); } catch (e) {}
        raiz.remove();
        resolve(valor);
      }

      var ultimoInvalido = '';
      function aoLer(texto) {
        var t = String(texto || '').trim();
        if (!t) return;
        if (!gtinValido(t)) {
          if (t !== ultimoInvalido) { ultimoInvalido = t; dica.textContent = 'Leitura falhou (' + t + '). Firme o celular e tente de novo.'; }
          return;
        }
        if (navigator.vibrate) navigator.vibrate(60);
        terminar(t);
      }

      fechar.onclick = function () { terminar(null); };
      bDigitar.onclick = function () { terminar('__DIGITAR__'); };

      // Foto: câmera nativa do celular (foco/macro do próprio iPhone).
      bFoto.onclick = function () { arquivo.click(); };
      arquivo.onchange = function () {
        var f = arquivo.files && arquivo.files[0];
        if (!f) return;
        dica.textContent = 'Lendo a foto...';
        decodificarFoto(f).then(function (texto) {
          if (texto) { aoLer(texto); return; }
          dica.textContent = 'Não achei código na foto. Enquadre só o código, com boa luz, e tente de novo.';
          arquivo.value = '';
        });
      };

      var restricoes = {
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          focusMode: { ideal: 'continuous' }
        },
        audio: false
      };

      leitor.decodeFromConstraints(restricoes, video, function (resultado) {
        if (resultado) aoLer(resultado.getText());
      }).then(function () {
        stream = video.srcObject;
        var trilha = stream && stream.getVideoTracks ? stream.getVideoTracks()[0] : null;
        var cap = trilha && trilha.getCapabilities ? trilha.getCapabilities() : {};
        // Foco contínuo, se o aparelho deixar.
        if (cap.focusMode && cap.focusMode.indexOf('continuous') >= 0) {
          trilha.applyConstraints({ advanced: [{ focusMode: 'continuous' }] }).catch(function () {});
        }
        // Zoom: permite ler de mais longe (imagem nítida) com o código grande.
        if (cap.zoom && cap.zoom.max > 1) {
          var niveis = [1, 2, 3].filter(function (z) { return z <= cap.zoom.max; });
          var i = 0;
          bZoom.style.display = '';
          bZoom.onclick = function () {
            i = (i + 1) % niveis.length;
            trilha.applyConstraints({ advanced: [{ zoom: niveis[i] }] }).catch(function () {});
            bZoom.textContent = 'Zoom ' + niveis[i] + 'x';
          };
        }
        // Lanterna só se o navegador suportar (o Safari do iPhone não suporta).
        if (cap.torch) {
          var ligada = false;
          bLuz.style.display = '';
          bLuz.onclick = function () {
            ligada = !ligada;
            trilha.applyConstraints({ advanced: [{ torch: ligada }] }).catch(function () {});
            bLuz.textContent = ligada ? 'Lanterna ✓' : 'Lanterna';
          };
        }
      }).catch(function () {
        video.style.display = 'none';
        dica.textContent = 'Sem acesso à câmera ao vivo. Use "📷 Foto do código" ou "Digitar". No iPhone: Ajustes > Safari > Câmera > Permitir.';
      });
    });
  }

  window.cicScanner = { abrir: abrir, decodificarFoto: decodificarFoto };
})();
