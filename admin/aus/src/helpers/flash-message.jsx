export default function flashMessage(message, consoleMessage = false) {
  const display = document.createElement('div')

  display.style.position = 'fixed';
  display.style.display = 'flex';
  display.style.color = '#fff';
  display.style.fontSize = '2rem';
  display.style.top = 0;
  display.style.left = 0;
  display.style.right = 0;
  display.style.width = '100vw';
  display.style.height = '4rem';
  display.style.background = '#027';
  display.style.justifyContent = 'center';
  display.style.alignItems = 'center';
  display.style.zIndex = '2500';
  display.innerText = message
  document.body.appendChild(display);
  console.log(consoleMessage || message);

  setTimeout(() => {
    document.body.removeChild(display);
  }, 1750)
}
