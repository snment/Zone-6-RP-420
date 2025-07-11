// UI State Management
let isUIVisible = false;

// DOM Elements
const container = document.getElementById('container');
const closeBtn = document.getElementById('closeBtn');
const createBtn = document.getElementById('createBtn');
const cancelBtn = document.getElementById('cancelBtn');
const clearAllBtn = document.getElementById('clearAllBtn'); // Added

// Form Elements
const itemInput = document.getElementById('item');
const amountInput = document.getElementById('amount');
const durationInput = document.getElementById('duration');
const blipNameInput = document.getElementById('blipName');
const blipSpriteInput = document.getElementById('blipSprite');
const blipColorSelect = document.getElementById('blipColor');
const blipScaleInput = document.getElementById('blipScale');
const radiusInput = document.getElementById('radius');

// Initialize UI
function initializeUI() {
    console.log('Initializing UI...');
    
    // Remove existing listeners to prevent duplicates
    closeBtn.removeEventListener('click', closeUI);
    cancelBtn.removeEventListener('click', closeUI);
    createBtn.removeEventListener('click', createInteractionPoint);
    clearAllBtn.removeEventListener('click', clearAllPoints); // Added

    closeBtn.addEventListener('click', function(e) {
        e.preventDefault();
        console.log('Close button clicked');
        closeUI();
    });
    
    cancelBtn.addEventListener('click', function(e) {
        e.preventDefault();
        console.log('Cancel button clicked');
        closeUI();
    });
    
    createBtn.addEventListener('click', function(e) {
        e.preventDefault();
        console.log('Create button clicked');
        createInteractionPoint();
    });

    clearAllBtn.addEventListener('click', function(e) { // Added
        e.preventDefault();
        console.log('Clear All button clicked');
        clearAllPoints();
    });

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isUIVisible) {
            console.log('Escape key pressed, closing UI');
            e.preventDefault();
            closeUI();
        }
        if (e.key === 'Enter' && isUIVisible && document.activeElement.tagName !== 'INPUT') {
            console.log('Enter key pressed, creating point');
            e.preventDefault();
            createInteractionPoint();
        }
    });

    setupInputValidation();
    console.log('UI initialized successfully');
}

// Setup input validation
function setupInputValidation() {
    console.log('Setting up input validation...');
    
    itemInput.addEventListener('input', function() {
        this.style.borderColor = this.value.trim().length > 0 ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)';
    });

    amountInput.addEventListener('input', function() {
        const value = parseInt(this.value);
        this.style.borderColor = (value >= 1 && value <= 999) ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)';
    });

    durationInput.addEventListener('input', function() {
        const value = parseInt(this.value);
        this.style.borderColor = (value >= 0 && value <= 3600) ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)';
    });

    blipSpriteInput.addEventListener('input', function() {
        const value = parseInt(this.value);
        this.style.borderColor = (value >= 1 && value <= 826) ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)';
    });

    blipScaleInput.addEventListener('input', function() {
        const value = parseFloat(this.value);
        this.style.borderColor = (value >= 0.1 && value <= 2.0) ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)';
    });

    radiusInput.addEventListener('input', function() {
        const value = parseFloat(this.value);
        this.style.borderColor = (value >= 0.5 && value <= 10.0) ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)';
    });
    
    console.log('Input validation set up');
}

// Show UI
function showUI() {
    if (isUIVisible) {
        console.log('UI already visible, ignoring show request');
        return;
    }
    isUIVisible = true;
    container.classList.remove('hidden');
    container.style.animation = 'slideIn 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
    setTimeout(() => itemInput.focus(), 100);
    console.log('UI shown');
}

// Hide UI
function closeUI() {
    if (!isUIVisible) {
        console.log('UI already hidden, ignoring close request');
        return;
    }
    isUIVisible = false;
    container.style.animation = 'slideOut 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
    setTimeout(() => {
        container.classList.add('hidden');
        resetForm();
    }, 300);

    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(error => {
        console.error('Failed to send close event to client:', error);
    });
    
    console.log('UI closed');
}

// Reset form
function resetForm() {
    itemInput.value = '';
    amountInput.value = '1';
    durationInput.value = '0';
    blipNameInput.value = 'Interaction Point';
    blipSpriteInput.value = '478';
    blipColorSelect.value = '2';
    blipScaleInput.value = '0.8';
    radiusInput.value = '2.0';

    const inputs = document.querySelectorAll('input, select');
    inputs.forEach(input => input.style.borderColor = 'rgba(255, 255, 255, 0.1)');
    console.log('Form reset');
}

// Validate form
function validateForm() {
    console.log('Validating form...');
    const item = itemInput.value.trim();
    const amount = parseInt(amountInput.value);
    const duration = parseInt(durationInput.value);
    const blipSprite = parseInt(blipSpriteInput.value);
    const blipScale = parseFloat(blipScaleInput.value);
    const radius = parseFloat(radiusInput.value);

    if (!item) {
        showError('Please enter an item name');
        itemInput.focus();
        return false;
    }

    if (isNaN(amount) || amount < 1 || amount > 999) {
        showError('Amount must be between 1 and 999');
        amountInput.focus();
        return false;
    }

    if (isNaN(duration) || duration < 0 || duration > 3600) {
        showError('Duration must be between 0 and 3600 seconds');
        durationInput.focus();
        return false;
    }

    if (isNaN(blipSprite) || blipSprite < 1 || blipSprite > 826) {
        showError('Blip sprite must be between 1 and 826');
        blipSpriteInput.focus();
        return false;
    }

    if (isNaN(blipScale) || blipScale < 0.1 || blipScale > 2.0) {
        showError('Blip scale must be between 0.1 and 2.0');
        blipScaleInput.focus();
        return false;
    }

    if (isNaN(radius) || radius < 0.5 || radius > 10.0) {
        showError('Radius must be between 0.5 and 10.0');
        radiusInput.focus();
        return false;
    }

    console.log('Form validation passed');
    return true;
}

// Show error
function showError(message) {
    console.log('Showing error:', message);
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-notification';
    errorDiv.textContent = message;
    errorDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: rgba(239, 68, 68, 0.9);
        color: white;
        padding: 12px 20px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 500;
        z-index: 10000;
        animation: slideInRight 0.3s ease;
        box-shadow: 0 4px 15px rgba(239, 68, 68, 0.3);
    `;
    document.body.appendChild(errorDiv);

    setTimeout(() => {
        errorDiv.style.animation = 'slideOutRight 0.3s ease';
        setTimeout(() => errorDiv.parentNode?.removeChild(errorDiv), 300);
    }, 3000);
}

// Create interaction point
function createInteractionPoint() {
    console.log('=== CREATE INTERACTION POINT FUNCTION CALLED ===');
    
    if (!validateForm()) {
        console.log('Form validation failed');
        return;
    }

    if (createBtn.disabled) {
        console.log('Create button disabled, ignoring click');
        return;
    }

    createBtn.disabled = true;
    createBtn.textContent = 'Creating...';
    console.log('Create button disabled, sending request');

    const data = {
        item: itemInput.value.trim(),
        amount: parseInt(amountInput.value),
        duration: parseInt(durationInput.value),
        blipName: blipNameInput.value.trim() || 'Interaction Point',
        blipSprite: parseInt(blipSpriteInput.value),
        blipColor: parseInt(blipColorSelect.value),
        blipScale: parseFloat(blipScaleInput.value),
        radius: parseFloat(radiusInput.value)
    };

    console.log('Data to send:', data);
    
    const resourceName = GetParentResourceName();
    const url = `https://${resourceName}/createPoint`;
    
    console.log('Resource Name:', resourceName);
    console.log('URL:', url);

    fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    })
    .then(response => {
        console.log('Fetch response received:', response);
        console.log('Response status:', response.status);
        console.log('Response ok:', response.ok);
        
        createBtn.disabled = false;
        createBtn.textContent = 'Create Point';
        
        if (response.ok) {
            console.log('Point created successfully');
            closeUI();
        } else {
            console.error('Response not ok:', response.status);
            showError('Server responded with error: ' + response.status);
        }
    })
    .catch(error => {
        console.error('Fetch error:', error);
        createBtn.disabled = false;
        createBtn.textContent = 'Create Point';
        showError('Failed to create interaction point: ' + error.message);
    });
}

// Clear all points
function clearAllPoints() {
    console.log('=== CLEAR ALL POINTS FUNCTION CALLED ===');
    
    if (clearAllBtn.disabled) {
        console.log('Clear All button disabled, ignoring click');
        return;
    }

    clearAllBtn.disabled = true;
    clearAllBtn.textContent = 'Clearing...';
    console.log('Clear All button disabled, sending request');

    const resourceName = GetParentResourceName();
    const url = `https://${resourceName}/clearAllPoints`;
    
    console.log('Resource Name:', resourceName);
    console.log('URL:', url);

    fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    })
    .then(response => {
        console.log('Fetch response received:', response);
        console.log('Response status:', response.status);
        console.log('Response ok:', response.ok);
        
        clearAllBtn.disabled = false;
        clearAllBtn.textContent = 'Clear All';
        
        if (response.ok) {
            console.log('All points cleared successfully');
            showSuccess('All interaction points cleared');
            closeUI();
        } else {
            console.error('Response not ok:', response.status);
            showError('Server responded with error: ' + response.status);
        }
    })
    .catch(error => {
        console.error('Fetch error:', error);
        clearAllBtn.disabled = false;
        clearAllBtn.textContent = 'Clear All';
        showError('Failed to clear interaction points: ' + error.message);
    });
}

// Show success notification
function showSuccess(message) {
    console.log('Showing success:', message);
    const successDiv = document.createElement('div');
    successDiv.className = 'success-notification';
    successDiv.textContent = message;
    successDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: rgba(34, 197, 94, 0.9);
        color: white;
        padding: 12px 20px;
        border-radius: 8px;
        font-size: 14px;
        font-weight: 500;
        z-index: 10000;
        animation: slideInRight 0.3s ease;
        box-shadow: 0 4px 15px rgba(34, 197, 94, 0.3);
    `;
    document.body.appendChild(successDiv);

    setTimeout(() => {
        successDiv.style.animation = 'slideOutRight 0.3s ease';
        setTimeout(() => successDiv.parentNode?.removeChild(successDiv), 300);
    }, 3000);
}

// Test button click for debugging
function testButtonClick() {
    console.log('TEST BUTTON CLICKED!');
    alert('Button click detected!');
}

// Message handler
window.addEventListener('message', function(event) {
    console.log('Received NUI message:', event.data);
    const data = event.data;
    switch(data.type) {
        case 'show':
            showUI();
            if (data.items) {
                console.log('Received item list:', data.items);
                itemInput.value = ''; // Clear previous value
                const datalist = document.createElement('datalist');
                datalist.id = 'item-list';
                for (const item of data.items) {
                    const option = document.createElement('option');
                    option.value = item.name;
                    datalist.appendChild(option);
                }
                document.body.appendChild(datalist);
                itemInput.setAttribute('list', 'item-list');
            }
            break;
        case 'hide':
            closeUI();
            break;
    }
});

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideOut {
        from { opacity: 1; transform: translateY(0) scale(1); }
        to { opacity: 0; transform: translateY(-20px) scale(0.95); }
    }
    @keyframes slideInRight {
        from { opacity: 0; transform: translateX(100px); }
        to { opacity: 1; transform: translateX(0); }
    }
    @keyframes slideOutRight {
        from { opacity: 1; transform: translateX(0); }
        to { opacity: 0; transform: translateX(100px); }
    }
    .error-notification, .success-notification {
        backdrop-filter: blur(10px);
        -webkit-backdrop-filter: blur(10px);
    }
`;
document.head.appendChild(style);

// GetParentResourceName
function GetParentResourceName() {
    const url = window.location.href;
    const cfxMatch = url.match(/cfx-nui-([^\/]+)/);
    if (cfxMatch) {
        console.log('Resource name from CFX NUI URL:', cfxMatch[1]);
        return cfxMatch[1];
    }
    
    const nuiMatch = url.match(/nui:\/\/([^\/]+)/);
    if (nuiMatch) {
        console.log('Resource name from NUI URL:', nuiMatch[1]);
        return nuiMatch[1];
    }
    
    console.log('Using hostname as fallback:', window.location.hostname);
    return window.location.hostname;
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM Content Loaded, initializing UI');
    initializeUI();
});

// Debug function to test NUI communication
function testNUICallback() {
    console.log('Testing NUI callback...');
    const resourceName = GetParentResourceName();
    console.log('Resource name:', resourceName);
    
    fetch(`https://${resourceName}/debug`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ test: 'debug_message' })
    })
    .then(response => {
        console.log('Debug response:', response);
    })
    .catch(error => {
        console.error('Debug error:', error);
    });
}

// Log page load
window.addEventListener('load', function() {
    console.log('Page loaded, resource name:', GetParentResourceName());
    // testNUICallback(); // Uncomment for testing
});