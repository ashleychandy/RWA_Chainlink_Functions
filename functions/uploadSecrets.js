const { SecretsManager } = require("@chainlink/functions-toolkit");
const ethers = require("ethers");

async function uploadSecrets() {
  const routerAddress = "0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C";
  const donId = "fun-arbitrum-sepolia-1";
  const gatewayUrls = [
    "https://01.functions-gateway.testnet.chain.link/",
    "https://02.functions-gateway.testnet.chain.link/",
  ];

  const privateKey = process.env.PRIVATE_KEY;
  const rpcUrl = process.env.RPC_URL;
  const secrets = {
    alpacaKey: process.env.ALPACA_API_KEY,
    alpacaSecret: process.env.ALPACA_SECRET_KEY,
  };

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl); //connect w blockchain, interact w smart contracts
  const wallet = new ethers.Wallet(privateKey);
  const signer = wallet.connect(provider);

  const secretsManager = new SecretsManager({
    signer: signer,
    functionsRouterAddress: routerAddress,
    donId: donId,
  });

  await secretsManager.initialize();

  const encryptedSecrets = await secretsManager.encryptSecrets(secrets);
  const soltIdNumber = 0;
  const expirationTimeMinutes = 1440;

  const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
    encryptedSecretsHexstring: encryptedSecrets.encryptedSecrets,
    gatewayUrls: gatewayUrls,
    slotId: soltIdNumber,
    minutesUntilExpiration: expirationTimeMinutes,
  });

  if (!uploadResult.success) {
    throw new Error(`Failed to upload secrets ${uploadResult.errorMessage}`);
  }

  console.log(`\n Secrets Uploaded successfully, respone ${uploadResult}`);
  const donHostedSercetsVersion = parseInt(uploadResult.version);
  console.log(`Secrets version: ${donHostedSercetsVersion}`);
}

uploadSecrets().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
