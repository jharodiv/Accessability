module.exports = {
  branches: ["main"],
  repositoryUrl: "https://github.com/Arthritisboy/3Y2AAPWD.git",
  plugins: [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    ["@semantic-release/git", {
      assets: ["CHANGELOG.md", "package.json"],
      message: "chore(release): ${nextRelease.version} [skip ci]"
    }],
    ["@semantic-release/github", {
      assets: [
        { path: "frontend/build/app/outputs/flutter-apk/app-release.apk", label: "Android APK" }
      ]
    }]
  ]
};
