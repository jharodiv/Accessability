async function saveDeepLink(deviceId, code) {
  console.log("🔹 saveDeepLink called", { deviceId, code });
  try {
    const response = await fetch("https://3-y2-aapwd-8vze.vercel.app/api/save-deeplink", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ deviceId, inviteCode: code })
    });
    console.log("✅ saveDeepLink response:", response);
  } catch (err) {
    console.error("❌ Failed to save deeplink:", err);
  }
}

window.onload = async function() {
  console.log("🟢 Window loaded");

  const start = Date.now();

  // Get invite code from query params
  const params = new URLSearchParams(window.location.search);
  let code = params.get("code");
  const DEFAULT_CODE = "DEFAULT1234";

  if (!code) {
    console.warn("⚠️ No invite code found in URL, using default:", DEFAULT_CODE);
    code = DEFAULT_CODE;
  } else {
    console.log("📩 Invite code from URL:", code);
  }

  // Generate temporary deviceId
  const deviceId = crypto.randomUUID();
  console.log("🔑 Generated deviceId:", deviceId);

  // Save inviteCode → Redis via API
  console.log("💾 Saving invite code...");
  await saveDeepLink(deviceId, code);

  // Build deep link with deviceId
  let deepLink = "accessability://open/joinspace?deviceId=" + encodeURIComponent(deviceId);
  console.log("🔗 Deep link constructed:", deepLink);

  // Change background to indicate opening attempt
  document.body.style.backgroundColor = "#ffe0b2"; // light orange
  console.log("🎨 Background changed to light orange");

  // Try to open app
  console.log("🚀 Attempting to open app...");
  window.location = deepLink;

  // Fallback → if not installed, redirect to APK
  setTimeout(() => {
    const elapsed = Date.now() - start;
    console.log("⏱ Timeout triggered after", elapsed, "ms");

    if (elapsed >= 1500) {
      console.warn("⚠️ App likely not installed, redirecting to APK");
      document.body.style.backgroundColor = "#ffcccb"; // light red
      console.log("🎨 Background changed to light red");
      window.location = "https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk";
    }
  }, 1500);
};
