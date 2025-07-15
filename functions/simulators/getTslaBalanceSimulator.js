const requestConfig = require("../configs/getTslaBalanceConfig.js");

const {
  simulateScript,
  decodeResult,
} = require("@chainlink/functions-toolkit");

async function main() {
  const { responseBytesHexstring, errorString, capturedTerminalOutput } =
    await simulateScript(requestConfig);
  if (responseBytesHexstring) {
    console.log(
      `Response returned by script during local simulation: ${decodeResult(
        responseBytesHexstring,
        requestConfig.expectedReturnType
      ).toString()}\n`
    );
  }
  if (errorString) {
    console.log(`Error returned by Script ${errorString}\n`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
