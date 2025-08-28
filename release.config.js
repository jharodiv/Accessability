module.exports = {
  branches: ['release'],
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    '@semantic-release/github'
  ],
  preset: 'conventionalcommits',
  releaseRules: [
    { type: 'fix', release: 'patch' },
    { type: 'feat', release: 'minor' },
    { type: 'chore', release: 'minor' },
    { type: 'trigger', release: 'major' }, // your custom keyword
  ],
  parserOpts: {
    noteKeywords: ['BREAKING CHANGE', 'trigger']
  }
};
