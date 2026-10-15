// Some o splash quando o Flutter desenhar o primeiro quadro.
window.addEventListener('flutter-first-frame', function () {
  var el = document.getElementById('carregando');
  if (el) el.remove();
});
