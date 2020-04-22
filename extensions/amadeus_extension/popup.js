let activateButton = document.getElementById('activate_copy_clip');

chrome.storage.sync.get('color', function(data) {
  activateButton.style.backgroundColor = data.color;
  activateButton.setAttribute('value', data.color);
});

activateButton.onclick = function(element) {
  let color = element.target.value;
  chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
    chrome.tabs.executeScript(
      tabs[0].id,
      {
        file: 'copy-to-clipboard.js'
      }
    );
    chrome.tabs.insertCSS(
      tabs[0].id,
      {
        file: 'styles.css'
      }
    );
  });
};
