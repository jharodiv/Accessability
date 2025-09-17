window.onload = async function() {
  const start = Date.now();

  // Generate a random 6-digit default code if not provided in URL
  const DEFAULT_CODE = generateNumericCode();

  // Get code from query params, fallback to default
  const params = new URLSearchParams(window.location.search);
  let code = params.get("code") || DEFAULT_CODE;

  // Ensure the code is numeric and 6 digits (fallback to random if invalid)
  if (!/^\d{6}$/.test(code)) {
    console.warn("⚠️ Provided code is invalid. Using random 6-digit code.");
    code = DEFAULT_CODE;
  }

  console.log("✅ Using 6-digit code:", code);

  // Generate sessionId for API
  const sessionId = generateSessionId();
  console.log("📝 Generated session ID:", sessionId);

  try {
    // Store session → code mapping in API
    const stored = await storeSessionCode(sessionId, code);

    if (!stored) {
      console.error("❌ Failed to store session code");
      showManualDownload();
      return;
    }

    console.log("💾 Session code stored successfully");

    // Build deep link with sessionId
    const deepLink = `accessability://open/joinspace?code=${encodeURIComponent(sessionId)}`;
    window._deepLinkAttempted = true;

    // Try to open the app
    window.location.href = deepLink;

    // Fallback: redirect to APK if app not installed
    setTimeout(() => {
      if (!document.hidden && Date.now() - start >= 1500 && !window._deepLinkSucceeded) {
        const apkUrl = "https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk";
        console.log("📦 Redirecting to APK (session hidden)");
        window.location.href = apkUrl;
      }
    }, 1500);

  } catch (err) {
    console.error("❌ Error:", err);
    showManualDownload();
  }
};

// Generate unique session ID
function generateSessionId() {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 9);
  return `session_${timestamp}_${random}`;
}

// Generate a random 6-digit numeric code
function generateNumericCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Store session → code mapping via API
async function storeSessionCode(sessionId, code) {
  try {
    const response = await fetch('https://3-y2-aapwd-xqeh.vercel.app/api/store-session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sessionId, code })
    });

    if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
    const data = await response.json();
    return data.success === true;

  } catch (error) {
    console.error('Error storing session:', error);
    return false;
  }
}

// Manual download fallback
function showManualDownload() {
  document.body.innerHTML = '';
  const container = document.createElement('div');
  container.style.cssText = 'display: flex; justify-content: center; align-items: center; height: 100vh; text-align: center;';
  container.innerHTML = `
    <div>
      <h1>Download the App</h1>
      <p>Click the button below to download and install the app:</p>
      <a href="https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk" class="download-btn">
        Download APK
      </a>
      <p style="margin-top: 20px; font-size: 14px; color: #666;">
        The app will automatically detect your invite code after installation.
      </p>
    </div>
  `;
  document.body.appendChild(container);
}

// Visibility and reload handling
document.addEventListener('visibilitychange', () => { if (document.hidden) window._deepLinkSucceeded = true; });
window.addEventListener('beforeunload', () => { window._deepLinkAttempted = true; });
if (window._deepLinkAttempted && !window._deepLinkSucceeded) showManualDownload();
