module.exports = {
  root: true,
  env: {
    es6: true
  },
  "parserOptions": {
    "ecmaVersion": 6,
    "sourceType": "module",
},
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    quotes: ["error", "double"],
  },
};
