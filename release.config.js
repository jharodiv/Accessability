module.exports = {
  branches: ["main"],
  plugins: [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    [
      "@semantic-release/github",
      {
        assets: [
          {
            path: "frontend/build/app/outputs/flutter-apk/app-release.apk",
            label: "Android APK"
          }
        ]
      }
    ]
  ]
};
