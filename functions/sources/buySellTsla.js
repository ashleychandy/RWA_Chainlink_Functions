const SLEEP_TIME = 7000; // 10 seconds
let orderPlaced;

async function main() {
  console.log("buyTslaSimulator.js started");
  const quantityOfTsla = args[0];
  const orderType = args[1]; //buy/sell
  const userAddr = args[2];
  const orderId = args[3];

  const client_order_id = `${userAddr}${orderId}`;
  // const quantityOfTsla = "7";
  // const orderType = "buy"; //buy/sell
  _checkKeys();

  let orderStatus = checkOrderExists(client_order_id);

  let responseStatus;

  if (orderStatus !== 200) {
    responseStatus = await placeOrder(
      quantityOfTsla,
      orderType,
      client_order_id
    );
  }

  if (orderStatus === 402 || orderStatus === 403) {
    console.log(`Order placement failed with status: ${responseStatus}`);
    return Functions.encodeUint256(0);
  }

  let filled = await waitForOrderToFill(client_order_id);

  if (!filled) {
    console.log("Order was not filled within timeout period");
    // await cancelOrder(client_order_id);
    return Functions.encodeUint256(0);
  }

  const scaledQty = BigInt(quantityOfTsla) * 10n ** 18n;

  console.log("The number returneing shld be ", scaledQty);

  // Encode as uint256
  const encoded = Functions.encodeUint256(scaledQty);

  return encoded;

  // return Functions.encodeUint256(quantityOfTsla);
}

async function checkOrderExists(client_order_id) {
  const alpacaRequest = Functions.makeHttpRequest({
    url: `https://paper-api.alpaca.markets/v2/orders:${client_order_id}`,
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "APCA-API-KEY-ID": secrets.alpacaKey,
      "APCA-API-SECRET-KEY": secrets.alpacaSecret,
    },
  });
  const response = await alpacaRequest;

  return response.status;
}

async function placeOrder(qty, side, client_order_id) {
  const alpacaRequest = Functions.makeHttpRequest({
    url: "https://paper-api.alpaca.markets/v2/orders",
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "APCA-API-KEY-ID": secrets.alpacaKey,
      "APCA-API-SECRET-KEY": secrets.alpacaSecret,
    },
    data: {
      type: "market",
      time_in_force: "gtc",
      side: side,
      symbol: "TSLA",
      qty: qty,
      client_order_id: client_order_id,
    },
  });

  await sleep(SLEEP_TIME);

  const response = await alpacaRequest;

  const responseStatus = response.status;

  console.log(response);
  console.log(`\n\n`);

  console.log(`\n Response Status in place order ${responseStatus}\n\n`);
  console.log("client_order_id:", client_order_id);

  return responseStatus;
}

async function waitForOrderToFill(client_order_id) {
  let numberOfSleeps = 0;
  const capNumberOfSleeps = 5;
  let filled = false;

  console.log("Started to wait");

  while (numberOfSleeps < capNumberOfSleeps) {
    const alpacaRequest = await Functions.makeHttpRequest({
      method: `GET`,
      url: `https://paper-api.alpaca.markets/v2/orders:by_client_order_id?client_order_id=${client_order_id}`,
      headers: {
        accept: "application/json",
        "APCA-API-KEY-ID": secrets.alpacaKey,
        "APCA-API-SECRET-KEY": secrets.alpacaSecret,
      },
    });

    const response = await alpacaRequest;

    const responseStatus = response.status;

    console.log(`Order status check - Response Status: ${responseStatus}`);

    // if (responseStatus !== 200) {
    //   console.error(`Failed to get order status: ${responseStatus}`);
    //   return false;
    // }

    // Add null/undefined checks
    // if (!response.data) {
    //   console.error("Response data is undefined in order status check");
    //   return false;
    // }

    const orderStatus = response.data.status;
    console.log(`Order status: ${orderStatus}`);

    if (orderStatus === "filled" || orderStatus === "accepted") {
      filled = true;
      break;
    }

    console.log("numberOfSleeps: ", numberOfSleeps);

    numberOfSleeps++;
    await sleep(SLEEP_TIME);
  }
  return filled;
}

function _checkKeys() {
  if (secrets.alpacaKey == "" || secrets.alpacaSecret == "") {
    throw new Error("Need Alpaca Keys");
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const result = await main();
return result;
