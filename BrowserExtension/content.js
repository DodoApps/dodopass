// DodoPass Browser Extension - Content Script

// State
let currentDropdown = null;
let saveBanner = null;
let selectedIndex = 0;
let dropdownItems = [];
let activeField = null;
let totpInterval = null;

// Detect form type based on password fields
function detectFormType(form) {
  const context = form || document;
  const passwordFields = context.querySelectorAll('input[type="password"]:not([hidden]):not([style*="display: none"])');
  const visiblePasswordFields = Array.from(passwordFields).filter(f => isVisible(f));

  if (visiblePasswordFields.length === 0) {
    return { type: 'none', fields: [] };
  } else if (visiblePasswordFields.length === 1) {
    return { type: 'login', fields: visiblePasswordFields };
  } else if (visiblePasswordFields.length === 2) {
    // Could be registration (password + confirm) or login on some sites
    return { type: 'registration', fields: visiblePasswordFields };
  } else if (visiblePasswordFields.length >= 3) {
    // Password change form: current + new + confirm
    return { type: 'password_change', fields: visiblePasswordFields };
  }

  return { type: 'unknown', fields: visiblePasswordFields };
}

// Find login form fields
function findLoginFields() {
  const fields = {
    username: null,
    password: null
  };

  // Find password field
  const passwordFields = document.querySelectorAll('input[type="password"]:not([hidden]):not([style*="display: none"])');
  if (passwordFields.length > 0) {
    fields.password = passwordFields[0];
  }

  // Find username field
  if (fields.password) {
    const form = fields.password.closest('form');
    const searchContext = form || document;

    const usernameSelectors = [
      'input[type="email"]:not([hidden])',
      'input[type="text"][name*="user" i]:not([hidden])',
      'input[type="text"][name*="email" i]:not([hidden])',
      'input[type="text"][name*="login" i]:not([hidden])',
      'input[type="text"][id*="user" i]:not([hidden])',
      'input[type="text"][id*="email" i]:not([hidden])',
      'input[type="text"][id*="login" i]:not([hidden])',
      'input[autocomplete="username"]:not([hidden])',
      'input[autocomplete="email"]:not([hidden])'
    ];

    for (const selector of usernameSelectors) {
      const field = searchContext.querySelector(selector);
      if (field && isVisible(field)) {
        fields.username = field;
        break;
      }
    }

    // Fallback: find text input before password
    if (!fields.username && form) {
      const inputs = form.querySelectorAll('input[type="text"], input[type="email"]');
      for (const input of inputs) {
        if (isVisible(input) && input !== fields.password) {
          fields.username = input;
          break;
        }
      }
    }
  }

  return fields;
}

function isVisible(element) {
  if (!element) return false;
  const style = window.getComputedStyle(element);
  return style.display !== 'none' &&
         style.visibility !== 'hidden' &&
         style.opacity !== '0' &&
         element.offsetParent !== null;
}

// Fill credentials
function fillCredentials(username, password) {
  const fields = findLoginFields();

  if (fields.username && username) {
    setFieldValue(fields.username, username);
  }

  if (fields.password && password) {
    setFieldValue(fields.password, password);
  }

  closeDropdown();
  return !!(fields.username || fields.password);
}

function setFieldValue(field, value) {
  field.focus();
  field.value = value;
  field.dispatchEvent(new Event('input', { bubbles: true }));
  field.dispatchEvent(new Event('change', { bubbles: true }));

  // For React and other frameworks
  const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
    window.HTMLInputElement.prototype, 'value'
  ).set;
  nativeInputValueSetter.call(field, value);
  field.dispatchEvent(new Event('input', { bubbles: true }));
}

// Fill just password
function fillPassword(password) {
  const fields = findLoginFields();
  if (fields.password && password) {
    setFieldValue(fields.password, password);
    closeDropdown();
    return true;
  }
  return false;
}

// Create SVG elements safely
function createSvgIcon(type) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', type === 'lock' ? '24' : '18');
  svg.setAttribute('height', type === 'lock' ? '24' : '18');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');

  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');

  if (type === 'lock' || type === 'logo') {
    path.setAttribute('d', 'M12 2C9.243 2 7 4.243 7 7v3H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-1V7c0-2.757-2.243-5-5-5zm0 2c1.654 0 3 1.346 3 3v3H9V7c0-1.654 1.346-3 3-3zm0 10a2 2 0 1 1 0 4 2 2 0 0 1 0-4z');
    path.setAttribute('fill', 'currentColor');
  } else if (type === 'close') {
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    path.setAttribute('d', 'M18 6L6 18M6 6l12 12');
    path.setAttribute('stroke', 'currentColor');
    path.setAttribute('stroke-width', '2');
    path.setAttribute('stroke-linecap', 'round');
  }

  svg.appendChild(path);
  return svg;
}

// Create inline dropdown using DOM methods
async function showDropdown(targetField) {
  closeDropdown();
  activeField = targetField;

  const rect = targetField.getBoundingClientRect();

  const dropdown = document.createElement('div');
  dropdown.className = 'dodopass-dropdown';
  dropdown.style.top = `${rect.bottom + window.scrollY + 4}px`;
  dropdown.style.left = `${rect.left + window.scrollX}px`;

  // Header
  const header = document.createElement('div');
  header.className = 'dodopass-dropdown-header';

  const logo = document.createElement('div');
  logo.className = 'dodopass-dropdown-logo';
  logo.appendChild(createSvgIcon('logo'));
  const logoText = document.createElement('span');
  logoText.textContent = 'DodoPass';
  logo.appendChild(logoText);

  const closeBtn = document.createElement('button');
  closeBtn.className = 'dodopass-dropdown-close';
  closeBtn.appendChild(createSvgIcon('close'));
  closeBtn.addEventListener('click', closeDropdown);

  header.appendChild(logo);
  header.appendChild(closeBtn);

  // List container
  const list = document.createElement('div');
  list.className = 'dodopass-dropdown-list';

  // Footer
  const footer = document.createElement('div');
  footer.className = 'dodopass-dropdown-footer';
  const shortcut = document.createElement('span');
  shortcut.className = 'dodopass-dropdown-shortcut';
  shortcut.textContent = '↑↓ navigate  ↵ fill';
  footer.appendChild(shortcut);

  dropdown.appendChild(header);
  dropdown.appendChild(list);
  dropdown.appendChild(footer);

  document.body.appendChild(dropdown);
  currentDropdown = dropdown;

  // Load items
  await loadDropdownItems();

  // Keyboard navigation
  document.addEventListener('keydown', handleDropdownKeydown);
}

async function loadDropdownItems() {
  if (!currentDropdown) return;

  const listEl = currentDropdown.querySelector('.dodopass-dropdown-list');
  listEl.replaceChildren();

  try {
    // Check status first
    const status = await sendMessage({ action: 'getStatus' });

    if (!status.success || status.data?.locked) {
      const lockedDiv = document.createElement('div');
      lockedDiv.className = 'dodopass-dropdown-locked';
      lockedDiv.appendChild(createSvgIcon('lock'));
      const p1 = document.createElement('p');
      p1.textContent = 'Vault is locked';
      const p2 = document.createElement('p');
      p2.className = 'hint';
      p2.textContent = 'Open DodoPass to unlock';
      lockedDiv.appendChild(p1);
      lockedDiv.appendChild(p2);
      listEl.appendChild(lockedDiv);
      return;
    }

    // Get items for current URL
    const results = await sendMessage({ action: 'listForUrl', url: window.location.href });

    if (results.success && results.data?.items?.length > 0) {
      dropdownItems = results.data.items;
      selectedIndex = 0;
      renderDropdownItems();
    } else {
      const emptyDiv = document.createElement('div');
      emptyDiv.className = 'dodopass-dropdown-empty';
      emptyDiv.textContent = 'No passwords saved for this site';
      listEl.appendChild(emptyDiv);
    }
  } catch (error) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'dodopass-dropdown-empty';
    errorDiv.textContent = 'Cannot connect to DodoPass';
    listEl.appendChild(errorDiv);
  }
}

function renderDropdownItems() {
  if (!currentDropdown) return;

  const listEl = currentDropdown.querySelector('.dodopass-dropdown-list');
  listEl.replaceChildren();

  // Clear any existing TOTP interval
  if (totpInterval) {
    clearInterval(totpInterval);
    totpInterval = null;
  }

  dropdownItems.forEach((item, index) => {
    const itemEl = document.createElement('div');
    itemEl.className = `dodopass-dropdown-item${index === selectedIndex ? ' selected' : ''}`;

    const iconEl = document.createElement('div');
    iconEl.className = 'dodopass-dropdown-item-icon';
    iconEl.textContent = getInitial(item.title);

    const contentEl = document.createElement('div');
    contentEl.className = 'dodopass-dropdown-item-content';

    const titleEl = document.createElement('div');
    titleEl.className = 'dodopass-dropdown-item-title';
    titleEl.textContent = item.title;

    const subtitleEl = document.createElement('div');
    subtitleEl.className = 'dodopass-dropdown-item-subtitle';
    subtitleEl.textContent = item.username || '';

    contentEl.appendChild(titleEl);
    contentEl.appendChild(subtitleEl);

    // Add TOTP badge if available
    if (item.hasTotp) {
      const totpBadge = document.createElement('div');
      totpBadge.className = 'dodopass-dropdown-totp-badge';
      totpBadge.textContent = '2FA';
      totpBadge.title = 'Has two-factor authentication';
      contentEl.appendChild(totpBadge);
    }

    itemEl.appendChild(iconEl);
    itemEl.appendChild(contentEl);

    // Add TOTP copy button if item has TOTP
    if (item.hasTotp) {
      const totpBtn = document.createElement('button');
      totpBtn.className = 'dodopass-dropdown-totp-btn';
      totpBtn.title = 'Copy TOTP code';
      totpBtn.textContent = '2FA';
      totpBtn.addEventListener('click', async (e) => {
        e.stopPropagation();
        await copyTOTP(item.id);
      });
      itemEl.appendChild(totpBtn);
    }

    itemEl.addEventListener('click', () => fillFromItem(item));
    itemEl.addEventListener('mouseenter', () => {
      selectedIndex = index;
      renderDropdownItems();
    });

    listEl.appendChild(itemEl);
  });
}

// Copy TOTP code to clipboard
async function copyTOTP(itemId) {
  try {
    const response = await sendMessage({ action: 'getTOTP', id: itemId });
    if (response.success && response.data?.code) {
      await navigator.clipboard.writeText(response.data.code);
      showToast(`TOTP copied: ${response.data.code} (${response.data.remaining}s remaining)`);
    } else {
      showToast(response.error || 'Failed to get TOTP code');
    }
  } catch (error) {
    console.error('TOTP copy error:', error);
    showToast('Failed to copy TOTP');
  }
}

// Show a toast notification
function showToast(message) {
  // Remove any existing toast
  const existingToast = document.querySelector('.dodopass-toast');
  if (existingToast) existingToast.remove();

  const toast = document.createElement('div');
  toast.className = 'dodopass-toast';
  toast.textContent = message;
  document.body.appendChild(toast);

  // Fade in
  requestAnimationFrame(() => {
    toast.classList.add('show');
  });

  // Auto remove after 3 seconds
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

async function fillFromItem(item) {
  try {
    const creds = await sendMessage({ action: 'getCredentials', id: item.id });
    if (creds.success && creds.data) {
      fillCredentials(creds.data.username, creds.data.password);
    }
  } catch (error) {
    console.error('Fill error:', error);
  }
}

function handleDropdownKeydown(e) {
  if (!currentDropdown || dropdownItems.length === 0) return;

  switch (e.key) {
    case 'ArrowDown':
      e.preventDefault();
      selectedIndex = (selectedIndex + 1) % dropdownItems.length;
      renderDropdownItems();
      break;
    case 'ArrowUp':
      e.preventDefault();
      selectedIndex = (selectedIndex - 1 + dropdownItems.length) % dropdownItems.length;
      renderDropdownItems();
      break;
    case 'Enter':
      e.preventDefault();
      if (dropdownItems[selectedIndex]) {
        fillFromItem(dropdownItems[selectedIndex]);
      }
      break;
    case 'Escape':
      closeDropdown();
      break;
  }
}

function closeDropdown() {
  if (currentDropdown) {
    currentDropdown.remove();
    currentDropdown = null;
  }
  dropdownItems = [];
  selectedIndex = 0;
  activeField = null;
  document.removeEventListener('keydown', handleDropdownKeydown);
}

// Password save detection
function detectFormSubmit() {
  document.addEventListener('submit', handleFormSubmit, true);

  // Also detect click on submit buttons (for AJAX forms)
  document.addEventListener('click', (e) => {
    const button = e.target.closest('button[type="submit"], input[type="submit"], button:not([type])');
    if (button) {
      const form = button.closest('form');
      if (form) {
        setTimeout(() => checkForCredentialsToSave(form), 100);
      }
    }
  }, true);
}

function handleFormSubmit(e) {
  const form = e.target;
  checkForCredentialsToSave(form);
}

function checkForCredentialsToSave(form) {
  const formType = detectFormType(form);

  if (formType.type === 'none') return;

  // Handle password change form
  if (formType.type === 'password_change') {
    handlePasswordChangeForm(form, formType.fields);
    return;
  }

  // For login or registration forms, get the password
  const passwordField = formType.fields[formType.fields.length - 1]; // Last password field (in case of registration, this is confirm)
  const mainPasswordField = formType.fields[0]; // First password field

  if (!mainPasswordField || !mainPasswordField.value) return;

  // Find username field
  let usernameField = null;
  const usernameSelectors = [
    'input[type="email"]',
    'input[type="text"][name*="user" i]',
    'input[type="text"][name*="email" i]',
    'input[autocomplete="username"]'
  ];

  for (const selector of usernameSelectors) {
    usernameField = form.querySelector(selector);
    if (usernameField && usernameField.value) break;
  }

  if (!usernameField) {
    const textInputs = form.querySelectorAll('input[type="text"], input[type="email"]');
    for (const input of textInputs) {
      if (input.value && input !== mainPasswordField) {
        usernameField = input;
        break;
      }
    }
  }

  const username = usernameField?.value || '';
  const password = mainPasswordField.value;

  if (password) {
    checkAndShowSaveBanner(username, password);
  }
}

// Handle password change form (current + new + confirm)
function handlePasswordChangeForm(form, passwordFields) {
  if (passwordFields.length < 2) return;

  // Usually: [0] = current password, [1] = new password, [2] = confirm (optional)
  const currentPassword = passwordFields[0]?.value;
  const newPassword = passwordFields[1]?.value;

  if (!newPassword) return;

  // Try to find username from the page (not in form, but maybe in profile/header)
  const username = findUsernameOnPage();

  if (username && newPassword) {
    checkAndShowUpdateBanner(username, newPassword);
  }
}

// Try to find username displayed somewhere on the page
function findUsernameOnPage() {
  // Check common patterns for logged-in user display
  const selectors = [
    '[class*="user-name"]',
    '[class*="username"]',
    '[class*="user-email"]',
    '[class*="account-name"]',
    '[data-testid*="user"]',
    '.profile-name',
    '.account-email'
  ];

  for (const selector of selectors) {
    const el = document.querySelector(selector);
    if (el && el.textContent.trim()) {
      return el.textContent.trim();
    }
  }

  return null;
}

async function checkAndShowSaveBanner(username, password) {
  try {
    const status = await sendMessage({ action: 'getStatus' });
    if (!status.success || status.data?.locked) return;

    // Use checkExisting to see if we need to update or save new
    const checkResult = await sendMessage({
      action: 'checkExisting',
      url: window.location.href,
      username: username
    });

    if (checkResult.success && checkResult.data?.exists) {
      // Existing credential found - offer to update
      showUpdateBanner(username, password, checkResult.data.id, checkResult.data.title);
    } else {
      // New credential - offer to save
      showSaveBanner(username, password);
    }
  } catch (error) {
    console.error('Save check error:', error);
  }
}

async function checkAndShowUpdateBanner(username, newPassword) {
  try {
    const status = await sendMessage({ action: 'getStatus' });
    if (!status.success || status.data?.locked) return;

    const checkResult = await sendMessage({
      action: 'checkExisting',
      url: window.location.href,
      username: username
    });

    if (checkResult.success && checkResult.data?.exists) {
      showUpdateBanner(username, newPassword, checkResult.data.id, checkResult.data.title);
    }
  } catch (error) {
    console.error('Update check error:', error);
  }
}

async function showSaveBanner(username, password) {
  closeSaveBanner();

  const hostname = new URL(window.location.href).hostname.replace('www.', '');
  const title = document.title || hostname;

  // Check password strength and breach status in background
  let strengthInfo = null;
  let breachInfo = null;

  try {
    [strengthInfo, breachInfo] = await Promise.all([
      sendMessage({ action: 'getPasswordStrength', password }),
      sendMessage({ action: 'checkBreach', password })
    ]);
  } catch (e) {
    console.error('Password check error:', e);
  }

  const banner = document.createElement('div');
  banner.className = 'dodopass-save-banner';

  // Header
  const header = document.createElement('div');
  header.className = 'dodopass-save-banner-header';
  header.appendChild(createSvgIcon('logo'));
  const headerText = document.createElement('span');
  headerText.textContent = 'Save password?';
  header.appendChild(headerText);

  const closeBtn = document.createElement('button');
  closeBtn.className = 'dodopass-save-banner-close';
  closeBtn.appendChild(createSvgIcon('close'));
  closeBtn.addEventListener('click', closeSaveBanner);
  header.appendChild(closeBtn);

  // Content
  const content = document.createElement('div');
  content.className = 'dodopass-save-banner-content';

  const field1 = document.createElement('div');
  field1.className = 'dodopass-save-banner-field';
  const label1 = document.createElement('span');
  label1.className = 'dodopass-save-banner-label';
  label1.textContent = 'Website';
  const value1 = document.createElement('span');
  value1.className = 'dodopass-save-banner-value';
  value1.textContent = hostname;
  field1.appendChild(label1);
  field1.appendChild(value1);

  const field2 = document.createElement('div');
  field2.className = 'dodopass-save-banner-field';
  const label2 = document.createElement('span');
  label2.className = 'dodopass-save-banner-label';
  label2.textContent = 'Username';
  const value2 = document.createElement('span');
  value2.className = 'dodopass-save-banner-value';
  value2.textContent = username || '(none)';
  field2.appendChild(label2);
  field2.appendChild(value2);

  content.appendChild(field1);
  content.appendChild(field2);

  // Show breach/strength warning if applicable
  if (breachInfo?.success && breachInfo.data?.isBreached) {
    const warningDiv = document.createElement('div');
    warningDiv.className = 'dodopass-save-banner-warning breach';
    const warningIcon = document.createElement('span');
    warningIcon.className = 'warning-icon';
    warningIcon.textContent = '⚠️';
    warningDiv.appendChild(warningIcon);
    const warningText = document.createTextNode(` This password was found in ${breachInfo.data.count.toLocaleString()} data breaches`);
    warningDiv.appendChild(warningText);
    content.appendChild(warningDiv);
  } else if (strengthInfo?.success && strengthInfo.data?.level === 'Weak') {
    const warningDiv = document.createElement('div');
    warningDiv.className = 'dodopass-save-banner-warning weak';
    const warningIcon = document.createElement('span');
    warningIcon.className = 'warning-icon';
    warningIcon.textContent = '⚠️';
    warningDiv.appendChild(warningIcon);
    const warningText = document.createTextNode(' This password is weak. Consider using a stronger one.');
    warningDiv.appendChild(warningText);
    content.appendChild(warningDiv);
  } else if (strengthInfo?.success && strengthInfo.data?.level === 'Fair') {
    const warningDiv = document.createElement('div');
    warningDiv.className = 'dodopass-save-banner-warning fair';
    const warningIcon = document.createElement('span');
    warningIcon.className = 'warning-icon';
    warningIcon.textContent = 'ℹ️';
    warningDiv.appendChild(warningIcon);
    const warningText = document.createTextNode(' Password strength: Fair');
    warningDiv.appendChild(warningText);
    content.appendChild(warningDiv);
  }

  // Actions
  const actions = document.createElement('div');
  actions.className = 'dodopass-save-banner-actions';

  const dismissBtn = document.createElement('button');
  dismissBtn.className = 'dodopass-save-banner-btn secondary';
  dismissBtn.textContent = 'Not now';
  dismissBtn.addEventListener('click', closeSaveBanner);

  const saveBtn = document.createElement('button');
  saveBtn.className = 'dodopass-save-banner-btn primary';
  saveBtn.textContent = 'Save password';
  saveBtn.addEventListener('click', async () => {
    try {
      await sendMessage({
        action: 'saveCredentials',
        url: window.location.href,
        username: username,
        password: password,
        title: title
      });
      closeSaveBanner();
    } catch (error) {
      console.error('Save error:', error);
    }
  });

  actions.appendChild(dismissBtn);
  actions.appendChild(saveBtn);

  banner.appendChild(header);
  banner.appendChild(content);
  banner.appendChild(actions);

  document.body.appendChild(banner);
  saveBanner = banner;

  // Auto-dismiss after 10 seconds
  setTimeout(closeSaveBanner, 10000);
}

function closeSaveBanner() {
  if (saveBanner) {
    saveBanner.remove();
    saveBanner = null;
  }
}

// Show banner to update an existing password
function showUpdateBanner(username, password, itemId, itemTitle) {
  closeSaveBanner();

  const banner = document.createElement('div');
  banner.className = 'dodopass-save-banner';

  // Header
  const header = document.createElement('div');
  header.className = 'dodopass-save-banner-header';
  header.appendChild(createSvgIcon('logo'));
  const headerText = document.createElement('span');
  headerText.textContent = 'Update password?';
  header.appendChild(headerText);

  const closeBtn = document.createElement('button');
  closeBtn.className = 'dodopass-save-banner-close';
  closeBtn.appendChild(createSvgIcon('close'));
  closeBtn.addEventListener('click', closeSaveBanner);
  header.appendChild(closeBtn);

  // Content
  const content = document.createElement('div');
  content.className = 'dodopass-save-banner-content';

  const field1 = document.createElement('div');
  field1.className = 'dodopass-save-banner-field';
  const label1 = document.createElement('span');
  label1.className = 'dodopass-save-banner-label';
  label1.textContent = 'Login';
  const value1 = document.createElement('span');
  value1.className = 'dodopass-save-banner-value';
  value1.textContent = itemTitle;
  field1.appendChild(label1);
  field1.appendChild(value1);

  const field2 = document.createElement('div');
  field2.className = 'dodopass-save-banner-field';
  const label2 = document.createElement('span');
  label2.className = 'dodopass-save-banner-label';
  label2.textContent = 'Username';
  const value2 = document.createElement('span');
  value2.className = 'dodopass-save-banner-value';
  value2.textContent = username || '(none)';
  field2.appendChild(label2);
  field2.appendChild(value2);

  content.appendChild(field1);
  content.appendChild(field2);

  // Actions
  const actions = document.createElement('div');
  actions.className = 'dodopass-save-banner-actions';

  const dismissBtn = document.createElement('button');
  dismissBtn.className = 'dodopass-save-banner-btn secondary';
  dismissBtn.textContent = 'Not now';
  dismissBtn.addEventListener('click', closeSaveBanner);

  const updateBtn = document.createElement('button');
  updateBtn.className = 'dodopass-save-banner-btn primary';
  updateBtn.textContent = 'Update password';
  updateBtn.addEventListener('click', async () => {
    try {
      const result = await sendMessage({
        action: 'updateCredentials',
        id: itemId,
        password: password
      });
      if (result.success) {
        showToast('Password updated');
      } else {
        showToast(result.error || 'Failed to update password');
      }
      closeSaveBanner();
    } catch (error) {
      console.error('Update error:', error);
      showToast('Failed to update password');
    }
  });

  actions.appendChild(dismissBtn);
  actions.appendChild(updateBtn);

  banner.appendChild(header);
  banner.appendChild(content);
  banner.appendChild(actions);

  document.body.appendChild(banner);
  saveBanner = banner;

  // Auto-dismiss after 10 seconds
  setTimeout(closeSaveBanner, 10000);
}

// Field focus handling
function setupFieldListeners() {
  document.addEventListener('focusin', (e) => {
    const target = e.target;
    if (target.matches('input[type="password"], input[type="text"], input[type="email"]')) {
      const fields = findLoginFields();
      if (target === fields.username || target === fields.password) {
        // Small delay to not interfere with normal typing
        setTimeout(() => {
          if (document.activeElement === target && !currentDropdown) {
            showDropdown(target);
          }
        }, 300);
      }
    }
  });

  document.addEventListener('focusout', (e) => {
    // Close dropdown when clicking outside
    setTimeout(() => {
      if (currentDropdown && !currentDropdown.contains(document.activeElement)) {
        closeDropdown();
      }
    }, 150);
  });

  // Close on click outside
  document.addEventListener('click', (e) => {
    if (currentDropdown && !currentDropdown.contains(e.target) && e.target !== activeField) {
      closeDropdown();
    }
  });
}

// Message sending
function sendMessage(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage(message, (response) => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else {
        resolve(response);
      }
    });
  });
}

// Utilities
function getInitial(title) {
  return (title || '?')[0].toUpperCase();
}

// Listen for messages from background script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  switch (request.action) {
    case 'fillCredentials':
      const success = fillCredentials(request.username, request.password);
      sendResponse({ success });
      break;
    case 'fillPassword':
      const pwSuccess = fillPassword(request.password);
      sendResponse({ success: pwSuccess });
      break;
    case 'getFields':
      const fields = findLoginFields();
      sendResponse({
        hasUsername: !!fields.username,
        hasPassword: !!fields.password
      });
      break;
  }
  return true;
});

// Initialize
function init() {
  setupFieldListeners();
  detectFormSubmit();

  // Check if there's a login form
  const fields = findLoginFields();
  if (fields.password) {
    console.log('DodoPass: Login form detected');
  }
}

// Run when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

console.log('DodoPass content script loaded');
