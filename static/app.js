window.onload = function() {
  const start = Date.now();

  // Get code from query params
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");

  // Build deep link
  let deepLink = "accessability://open/joinspace";
  if (code) {
    deepLink += "?code=" + encodeURIComponent(code);
  }

  // Try to open the app
  window.location = deepLink;

  // Fallback: if app not installed, redirect to APK after 1.5s
  setTimeout(() => {
    if (Date.now() - start >= 1500) {
      window.location = "https://github.com/Montilla007/3Y2AAPWD/releases/latest/download/app-release.apk";
    }
  }, 1500);
};
