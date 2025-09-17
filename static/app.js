let sessionId = "";
let code = "";

// Generate unique session ID
function generateSessionId() {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 9);
  return `session_${timestamp}_${random}`;
}

// Generate random 6-digit numeric code
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
    console.error('❌ Error storing session:', error);
    return false;
  }
}

// Safe copy function with fallback
async function copyToClipboard(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    return navigator.clipboard.writeText(text);
  } else {
    const tempInput = document.createElement("input");
    tempInput.value = text;
    document.body.appendChild(tempInput);
    tempInput.select();
    document.execCommand("copy");
    document.body.removeChild(tempInput);
    return Promise.resolve();
  }
}

// Handle download button click
async function handleDownload() {
  try {
    await copyToClipboard(sessionId);
    alert("✅ Session ID copied! The app will use it automatically.");
  } catch (err) {
    console.warn("Clipboard copy failed:", err);
    alert("⚠️ Could not copy automatically. Please copy manually:\n" + sessionId);
  }

  window.location.href = "https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk";
}

window.onload = async function () {
  const start = Date.now();

  // Get code from query params (if present)
  const params = new URLSearchParams(window.location.search);
  const providedCode = params.get("code");

  if (providedCode && /^\d{6}$/.test(providedCode)) {
    code = providedCode;
  } else {
    console.warn("⚠️ No valid code in URL. Generating random 6-digit code.");
    code = generateNumericCode();
  }

  sessionId = generateSessionId();
  console.log("✅ Using 6-digit code:", code);
  console.log("📝 Generated session ID:", sessionId);

  const stored = await storeSessionCode(sessionId, code);
  if (!stored) console.error("⚠️ Failed to store session code. The app may not recognize it.");

  // ✅ Only display session info if running locally (localhost or 192.168.*)
  const isLocal = window.location.hostname === "localhost" || /^192\.168\./.test(window.location.hostname);
  if (isLocal) {
    document.getElementById("sessionDisplay").textContent =
      `Session ID: ${sessionId}\nCode: ${code}`;
  } else {
    document.getElementById("sessionDisplay").textContent = ""; // hide it
  }

  // Try to open the app via deep link
  const deepLink = `accessability://open/joinspace?code=${encodeURIComponent(sessionId)}`;
  window.location.href = deepLink;

  // Fallback: redirect to manual download if app not installed
  setTimeout(() => {
    if (!document.hidden && Date.now() - start >= 1500) {
      console.log("📦 App did not open. Showing manual download option.");
      document.querySelector(".container h1").textContent = "Couldn't open the app automatically.";
    }
  }, 1500);

  document.getElementById("downloadBtn").addEventListener("click", handleDownload);
};
