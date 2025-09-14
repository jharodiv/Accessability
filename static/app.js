window.onload = async function() {
  const start = Date.now();
  let appOpened = false;

  // Get code from query params
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");

  if (!code) {
    console.warn("⚠️ No code found in URL");
    showManualDownload();
    return;
  }

  console.log("✅ Found code in URL:", code);

  // Generate unique session ID
  const sessionId = generateSessionId();
  console.log("📝 Generated session ID:", sessionId);

  try {
    // Store session → code mapping in Redis via API
    const stored = await storeSessionCode(sessionId, code);
    
    if (stored) {
      console.log("💾 Session code stored successfully");
      
      // Build deep link with session ID (for warm start)
      let deepLink = "accessability://open/joinspace";
      deepLink += "?code=" + encodeURIComponent(code);
      deepLink += "&session=" + encodeURIComponent(sessionId);

      // Set flag to prevent double execution on page hide
      window._deepLinkAttempted = true;

      // Try to open the app (warm start)
      window.location.href = deepLink;
      appOpened = true;

      // Fallback: if app not installed, redirect to APK after delay
      setTimeout(() => {
        // If page is still visible after 1.5 seconds, app didn't open
        if (!document.hidden && Date.now() - start >= 1500 && !window._deepLinkSucceeded) {
          const apkUrl = `https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk?session=${sessionId}`;
          console.log("📦 Redirecting to APK with session:", sessionId);
          window.location.href = apkUrl;
        }
      }, 1500);

    } else {
      console.error("❌ Failed to store session code");
      showManualDownload();
    }

  } catch (error) {
    console.error("❌ Error:", error);
    showManualDownload();
  }
};

// Listen for page visibility changes (app opening success)
document.addEventListener('visibilitychange', function() {
  if (document.hidden) {
    console.log("✅ App opened successfully (page hidden)");
    window._deepLinkSucceeded = true;
  }
});

// Listen for page beforeunload (app opening attempt)
window.addEventListener('beforeunload', function() {
  window._deepLinkAttempted = true;
});

// Generate unique session ID
function generateSessionId() {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substr(2, 9);
  return `session_${timestamp}_${random}`;
}

// Store session → code mapping via API
async function storeSessionCode(sessionId, code) {
  try {
    const response = await fetch('https://3-y2-aapwd-xqeh.vercel.app/api/store-session', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        sessionId: sessionId,
        code: code
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data.success === true;

  } catch (error) {
    console.error('Error storing session:', error);
    return false;
  }
}

// Show manual download option
function showManualDownload() {
  // Remove any existing content
  document.body.innerHTML = '';
  
  const container = document.createElement('div');
  container.style.cssText = 'display: flex; justify-content: center; align-items: center; height: 100vh; text-align: center;';
  
  container.innerHTML = `
    <div>
      <h1>Download the App</h1>
      <p>Click the button below to download and install the app:</p>
      <a href="https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk" 
         class="download-btn">
        Download APK
      </a>
      <p style="margin-top: 20px; font-size: 14px; color: #666;">
        The app will automatically detect your invite code after installation.
      </p>
    </div>
  `;
  document.body.appendChild(container);
}

// Handle page reloads - if deep link was already attempted, go straight to download
if (window._deepLinkAttempted && !window._deepLinkSucceeded) {
  console.log("🔄 Page reloaded after deep link attempt - redirecting to APK");
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  const sessionId = generateSessionId();
  
  if (code) {
    const apkUrl = `https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk?session=${sessionId}`;
    window.location.href = apkUrl;
  } else {
    showManualDownload();
  }
}