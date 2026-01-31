// DodoPass Browser Extension - Background Service Worker

const NATIVE_HOST = 'com.dodopass.host';

// State
let port = null;
let pendingRequests = new Map();
let requestId = 0;

// Connect to native host
function connectNative() {
  if (port) {
    return port;
  }

  try {
    port = chrome.runtime.connectNative(NATIVE_HOST);

    port.onMessage.addListener((response) => {
      console.log('Received from native:', response);

      // Handle response
      if (response.requestId && pendingRequests.has(response.requestId)) {
        const { resolve } = pendingRequests.get(response.requestId);
        pendingRequests.delete(response.requestId);
        resolve(response);
      }
    });

    port.onDisconnect.addListener(() => {
      console.log('Native host disconnected:', chrome.runtime.lastError?.message);
      port = null;

      // Reject all pending requests
      for (const [id, { reject }] of pendingRequests) {
        reject(new Error('Native host disconnected'));
      }
      pendingRequests.clear();
    });

    return port;
  } catch (error) {
    console.error('Failed to connect to native host:', error);
    return null;
  }
}

// Send message to native host
function sendNativeMessage(command, params = {}) {
  return new Promise((resolve, reject) => {
    const currentPort = connectNative();

    if (!currentPort) {
      reject(new Error('Cannot connect to DodoPass. Is the app running?'));
      return;
    }

    const id = ++requestId;
    const message = {
      requestId: id,
      command,
      params
    };

    pendingRequests.set(id, { resolve, reject });

    // Timeout after 5 seconds
    setTimeout(() => {
      if (pendingRequests.has(id)) {
        pendingRequests.delete(id);
        reject(new Error('Request timed out'));
      }
    }, 5000);

    currentPort.postMessage(message);
  });
}

// API for popup and content scripts
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  (async () => {
    try {
      switch (request.action) {
        case 'getStatus':
          const status = await sendNativeMessage('status');
          sendResponse(status);
          break;

        case 'search':
          const searchResults = await sendNativeMessage('search', { query: request.query });
          sendResponse(searchResults);
          break;

        case 'listForUrl':
          const urlResults = await sendNativeMessage('listForUrl', { url: request.url });
          sendResponse(urlResults);
          break;

        case 'getCredentials':
          const credentials = await sendNativeMessage('getCredentials', { id: request.id });
          sendResponse(credentials);
          break;

        case 'lock':
          const lockResult = await sendNativeMessage('lock');
          sendResponse(lockResult);
          break;

        case 'unlock':
          const unlockResult = await sendNativeMessage('unlock', { password: request.password });
          sendResponse(unlockResult);
          break;

        case 'saveCredentials':
          const saveResult = await sendNativeMessage('saveCredentials', {
            url: request.url,
            username: request.username,
            password: request.password,
            title: request.title
          });
          sendResponse(saveResult);
          break;

        case 'updateCredentials':
          const updateResult = await sendNativeMessage('updateCredentials', {
            id: request.id,
            username: request.username,
            password: request.password
          });
          sendResponse(updateResult);
          break;

        case 'checkExisting':
          const checkResult = await sendNativeMessage('checkExisting', {
            url: request.url,
            username: request.username
          });
          sendResponse(checkResult);
          break;

        case 'getTOTP':
          const totpResult = await sendNativeMessage('getTOTP', { id: request.id });
          sendResponse(totpResult);
          break;

        case 'checkBreach':
          const breachResult = await sendNativeMessage('checkBreach', { password: request.password });
          sendResponse(breachResult);
          break;

        case 'getPasswordStrength':
          const strengthResult = await sendNativeMessage('getPasswordStrength', { password: request.password });
          sendResponse(strengthResult);
          break;

        case 'fill':
          // Send credentials to content script
          if (sender.tab) {
            chrome.tabs.sendMessage(sender.tab.id, {
              action: 'fillCredentials',
              username: request.username,
              password: request.password
            });
          }
          sendResponse({ success: true });
          break;

        default:
          sendResponse({ success: false, error: 'Unknown action' });
      }
    } catch (error) {
      sendResponse({ success: false, error: error.message });
    }
  })();

  return true; // Keep message channel open for async response
});

// Handle keyboard shortcuts
chrome.commands.onCommand.addListener(async (command) => {
  if (command === 'fill_credentials') {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (!tab) return;

      // Get credentials for current URL
      const results = await sendNativeMessage('listForUrl', { url: tab.url });

      if (results.success && results.data?.items?.length > 0) {
        const firstItem = results.data.items[0];
        const creds = await sendNativeMessage('getCredentials', { id: firstItem.id });

        if (creds.success && creds.data) {
          chrome.tabs.sendMessage(tab.id, {
            action: 'fillCredentials',
            username: creds.data.username,
            password: creds.data.password
          });
        }
      } else {
        // No credentials found - show notification or open popup
        chrome.action.openPopup();
      }
    } catch (error) {
      console.error('Fill credentials shortcut error:', error);
    }
  }
});

// Context menu for autofill
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'dodopass-fill',
    title: 'Fill with DodoPass',
    contexts: ['editable']
  });

  chrome.contextMenus.create({
    id: 'dodopass-generate',
    title: 'Generate password',
    contexts: ['editable']
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'dodopass-fill') {
    try {
      const results = await sendNativeMessage('listForUrl', { url: tab.url });
      if (results.success && results.data?.items?.length > 0) {
        const firstItem = results.data.items[0];
        const creds = await sendNativeMessage('getCredentials', { id: firstItem.id });

        if (creds.success) {
          chrome.tabs.sendMessage(tab.id, {
            action: 'fillCredentials',
            username: creds.data.username,
            password: creds.data.password
          });
        }
      }
    } catch (error) {
      console.error('Autofill error:', error);
    }
  } else if (info.menuItemId === 'dodopass-generate') {
    try {
      const password = generatePassword();
      chrome.tabs.sendMessage(tab.id, {
        action: 'fillPassword',
        password: password
      });
    } catch (error) {
      console.error('Generate password error:', error);
    }
  }
});

// Simple password generator
function generatePassword(length = 20) {
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const numbers = '0123456789';
  const symbols = '!@#$%^&*()_+-=[]{}|;:,.<>?';
  const allChars = uppercase + lowercase + numbers + symbols;

  let password = '';

  // Ensure at least one of each type
  password += uppercase[Math.floor(Math.random() * uppercase.length)];
  password += lowercase[Math.floor(Math.random() * lowercase.length)];
  password += numbers[Math.floor(Math.random() * numbers.length)];
  password += symbols[Math.floor(Math.random() * symbols.length)];

  // Fill the rest
  for (let i = password.length; i < length; i++) {
    password += allChars[Math.floor(Math.random() * allChars.length)];
  }

  // Shuffle
  return password.split('').sort(() => Math.random() - 0.5).join('');
}

console.log('DodoPass background service worker loaded');
