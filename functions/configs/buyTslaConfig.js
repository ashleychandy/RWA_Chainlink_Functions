const fs = require("fs");
const {
  Location,
  ReturnType,
  CodeLanguage,
} = require("@chainlink/functions-toolkit");

const requestConfig = {
  source: fs.readFileSync("./functions/sources/buySellTsla.js").toString(),
  codeLocation: Location.Inline,
  secrets: {
    alpacaKey: process.env.ALPACA_API_KEY,
    alpacaSecret: process.env.ALPACA_SECRET_KEY,
  },
  secretsLocation: Location.DONHosted,
  args: ["1","buy"],
  CodeLanguage: CodeLanguage.JavaScript,
  expectedReturnType: ReturnType.int256,
};

module.exports = requestConfig;
