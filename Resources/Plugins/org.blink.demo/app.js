'use strict';
(async () => {
  const status = document.querySelector('#status');
  const note = document.querySelector('#note');
  const save = document.querySelector('#save');
  try {
    const host = await blink.host.info();
    document.querySelector('#host').textContent = JSON.stringify(host, null, 2);
    note.value = await blink.storage.get('note') || '';
    save.disabled = false;
    save.addEventListener('click', async () => {
      try { await blink.storage.set('note', note.value); status.textContent = 'Saved. Close and reopen this app to check persistence.'; }
      catch (error) { status.textContent = String(error); }
    });
  } catch (error) { status.textContent = String(error); }
})();
