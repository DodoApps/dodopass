// DodoPass Browser Extension - Popup Script

// Elements
const statusEl = document.getElementById('status');
const lockedView = document.getElementById('lockedView');
const notRunningView = document.getElementById('notRunningView');
const mainView = document.getElementById('mainView');
const searchInput = document.getElementById('searchInput');
const pageMatches = document.getElementById('pageMatches');
const pageMatchesList = document.getElementById('pageMatchesList');
const searchResults = document.getElementById('searchResults');
const searchResultsList = document.getElementById('searchResultsList');
const emptyState = document.getElementById('emptyState');
const lockBtn = document.getElementById('lockBtn');
const unlockPassword = document.getElementById('unlockPassword');
const unlockBtn = document.getElementById('unlockBtn');

// State
let currentUrl = '';
let searchTimeout = null;

// Initialize
async function init() {
  // Get current tab URL
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  currentUrl = tab?.url || '';

  // Check status
  await checkStatus();

  // Setup event listeners
  searchInput.addEventListener('input', handleSearch);
  lockBtn.addEventListener('click', handleLock);
  unlockBtn.addEventListener('click', handleUnlock);
  unlockPassword.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      handleUnlock();
    }
  });
}

// Check vault status
async function checkStatus() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getStatus' });

    if (!response || response.error) {
      showView('notRunning');
      return;
    }

    if (!response.success) {
      showStatus(response.error || 'Connection error', 'error');
      showView('notRunning');
      return;
    }

    if (response.data?.locked) {
      showView('locked');
      return;
    }

    showView('main');
    await loadPageMatches();
  } catch (error) {
    console.error('Status check error:', error);
    showView('notRunning');
  }
}

// Show a specific view
function showView(view) {
  lockedView.classList.add('hidden');
  notRunningView.classList.add('hidden');
  mainView.classList.add('hidden');

  switch (view) {
    case 'locked':
      lockedView.classList.remove('hidden');
      unlockPassword.focus();
      break;
    case 'notRunning':
      notRunningView.classList.remove('hidden');
      break;
    case 'main':
      mainView.classList.remove('hidden');
      searchInput.focus();
      break;
  }
}

// Show status message
function showStatus(message, type = 'info') {
  statusEl.textContent = message;
  statusEl.className = `status ${type}`;
  statusEl.classList.remove('hidden');

  setTimeout(() => {
    statusEl.classList.add('hidden');
  }, 3000);
}

// Handle unlock
async function handleUnlock() {
  const password = unlockPassword.value;
  if (!password) {
    showStatus('Please enter your password', 'error');
    return;
  }

  unlockBtn.disabled = true;
  unlockBtn.textContent = 'Unlocking...';

  try {
    const response = await chrome.runtime.sendMessage({
      action: 'unlock',
      password: password
    });

    if (response.success) {
      unlockPassword.value = '';
      showView('main');
      await loadPageMatches();
    } else {
      showStatus(response.error || 'Failed to unlock', 'error');
      unlockPassword.select();
    }
  } catch (error) {
    console.error('Unlock error:', error);
    showStatus('Unlock failed', 'error');
  } finally {
    unlockBtn.disabled = false;
    unlockBtn.textContent = 'Unlock';
  }
}

// Load matches for current page
async function loadPageMatches() {
  if (!currentUrl) return;

  try {
    const response = await chrome.runtime.sendMessage({
      action: 'listForUrl',
      url: currentUrl
    });

    if (response.success && response.data?.items?.length > 0) {
      renderItems(response.data.items, pageMatchesList);
      pageMatches.classList.remove('hidden');
    } else {
      pageMatches.classList.add('hidden');
    }
  } catch (error) {
    console.error('Load page matches error:', error);
  }
}

// Handle search input
function handleSearch(e) {
  const query = e.target.value.trim();

  // Clear previous timeout
  if (searchTimeout) {
    clearTimeout(searchTimeout);
  }

  if (!query) {
    searchResults.classList.add('hidden');
    emptyState.classList.add('hidden');
    return;
  }

  // Debounce search
  searchTimeout = setTimeout(async () => {
    try {
      const response = await chrome.runtime.sendMessage({
        action: 'search',
        query: query
      });

      if (response.success && response.data?.items?.length > 0) {
        renderItems(response.data.items, searchResultsList);
        searchResults.classList.remove('hidden');
        emptyState.classList.add('hidden');
      } else {
        searchResults.classList.add('hidden');
        emptyState.classList.remove('hidden');
      }
    } catch (error) {
      console.error('Search error:', error);
    }
  }, 200);
}

// Create an item element safely using DOM methods
function createItemElement(item) {
  const itemEl = document.createElement('div');
  itemEl.className = 'item';

  // Icon
  const iconEl = document.createElement('div');
  iconEl.className = 'item-icon';
  iconEl.textContent = getInitial(item.title);

  // Content
  const contentEl = document.createElement('div');
  contentEl.className = 'item-content';

  const titleRow = document.createElement('div');
  titleRow.className = 'item-title-row';

  const titleEl = document.createElement('div');
  titleEl.className = 'item-title';
  titleEl.textContent = item.title;

  titleRow.appendChild(titleEl);

  // Add TOTP badge if available
  if (item.hasTotp) {
    const totpBadge = document.createElement('span');
    totpBadge.className = 'totp-badge';
    totpBadge.textContent = '2FA';
    titleRow.appendChild(totpBadge);
  }

  const subtitleEl = document.createElement('div');
  subtitleEl.className = 'item-subtitle';
  subtitleEl.textContent = item.username || '';

  contentEl.appendChild(titleRow);
  contentEl.appendChild(subtitleEl);

  // Actions
  const actionsEl = document.createElement('div');
  actionsEl.className = 'item-actions';

  // Fill button
  const fillBtn = document.createElement('button');
  fillBtn.className = 'action-btn fill-btn';
  fillBtn.title = 'Fill credentials';

  const fillSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  fillSvg.setAttribute('width', '14');
  fillSvg.setAttribute('height', '14');
  fillSvg.setAttribute('viewBox', '0 0 24 24');
  fillSvg.setAttribute('fill', 'none');
  const fillPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  fillPath.setAttribute('d', 'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a.996.996 0 0 0 0-1.41l-2.34-2.34a.996.996 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z');
  fillPath.setAttribute('fill', 'currentColor');
  fillSvg.appendChild(fillPath);
  fillBtn.appendChild(fillSvg);

  // Copy button
  const copyBtn = document.createElement('button');
  copyBtn.className = 'action-btn copy-btn';
  copyBtn.title = 'Copy password';

  const copySvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  copySvg.setAttribute('width', '14');
  copySvg.setAttribute('height', '14');
  copySvg.setAttribute('viewBox', '0 0 24 24');
  copySvg.setAttribute('fill', 'none');
  const copyPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  copyPath.setAttribute('d', 'M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z');
  copyPath.setAttribute('fill', 'currentColor');
  copySvg.appendChild(copyPath);
  copyBtn.appendChild(copySvg);

  actionsEl.appendChild(fillBtn);
  actionsEl.appendChild(copyBtn);

  // Add TOTP copy button if available
  if (item.hasTotp) {
    const totpBtn = document.createElement('button');
    totpBtn.className = 'action-btn totp-btn';
    totpBtn.title = 'Copy TOTP code';

    const totpSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    totpSvg.setAttribute('width', '14');
    totpSvg.setAttribute('height', '14');
    totpSvg.setAttribute('viewBox', '0 0 24 24');
    totpSvg.setAttribute('fill', 'none');
    const totpPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    totpPath.setAttribute('d', 'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z');
    totpPath.setAttribute('fill', 'currentColor');
    totpSvg.appendChild(totpPath);
    totpBtn.appendChild(totpSvg);

    totpBtn.addEventListener('click', async (e) => {
      e.stopPropagation();
      await copyTOTP(item.id);
    });

    actionsEl.appendChild(totpBtn);
  }

  itemEl.appendChild(iconEl);
  itemEl.appendChild(contentEl);
  itemEl.appendChild(actionsEl);

  // Event listeners
  fillBtn.addEventListener('click', async (e) => {
    e.stopPropagation();
    await fillCredentials(item.id);
  });

  copyBtn.addEventListener('click', async (e) => {
    e.stopPropagation();
    await copyPassword(item.id);
  });

  itemEl.addEventListener('click', () => fillCredentials(item.id));

  return itemEl;
}

// Render items to a list
function renderItems(items, container) {
  container.replaceChildren();

  items.forEach(item => {
    const itemEl = createItemElement(item);
    container.appendChild(itemEl);
  });
}

// Fill credentials into page
async function fillCredentials(itemId) {
  try {
    const response = await chrome.runtime.sendMessage({
      action: 'getCredentials',
      id: itemId
    });

    if (response.success && response.data) {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

      await chrome.tabs.sendMessage(tab.id, {
        action: 'fillCredentials',
        username: response.data.username,
        password: response.data.password
      });

      showStatus('Credentials filled', 'success');
      window.close();
    } else {
      showStatus(response.error || 'Failed to get credentials', 'error');
    }
  } catch (error) {
    console.error('Fill error:', error);
    showStatus('Fill failed', 'error');
  }
}

// Copy password to clipboard
async function copyPassword(itemId) {
  try {
    const response = await chrome.runtime.sendMessage({
      action: 'getCredentials',
      id: itemId
    });

    if (response.success && response.data?.password) {
      await navigator.clipboard.writeText(response.data.password);
      showStatus('Password copied', 'success');
    } else {
      showStatus(response.error || 'Failed to copy', 'error');
    }
  } catch (error) {
    console.error('Copy error:', error);
    showStatus('Copy failed', 'error');
  }
}

// Copy TOTP code to clipboard
async function copyTOTP(itemId) {
  try {
    const response = await chrome.runtime.sendMessage({
      action: 'getTOTP',
      id: itemId
    });

    if (response.success && response.data?.code) {
      await navigator.clipboard.writeText(response.data.code);
      showStatus(`TOTP copied: ${response.data.code} (${response.data.remaining}s)`, 'success');
    } else {
      showStatus(response.error || 'Failed to get TOTP', 'error');
    }
  } catch (error) {
    console.error('TOTP copy error:', error);
    showStatus('Copy TOTP failed', 'error');
  }
}

// Handle lock button
async function handleLock() {
  try {
    await chrome.runtime.sendMessage({ action: 'lock' });
    showView('locked');
  } catch (error) {
    console.error('Lock error:', error);
  }
}

// Utilities
function getInitial(title) {
  return (title || '?')[0].toUpperCase();
}

// Start
init();
