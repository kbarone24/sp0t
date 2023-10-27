module.exports = {
  root: true,
  parserOptions: {
    "ecmaVersion": "latest",
    "sourceType": "module",
},
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "quotes": ["error", "double"],
    "max-len": "off",
    "semi": ["error", "never"],
  },
};
