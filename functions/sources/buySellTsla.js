const SLEEP_TIME = 5000; // 5 seconds

async function main() {
  console.log("buyTslaSimulator.js started");
  // const quantityOfTsla = args[0];
  // const orderType = args[1]; //buy/sell
  const quantityOfTsla = "7";
  const orderType = "buy"; //buy/sell
  _checkKeys();

  let [client_order_id, orderStatus, responseStatus] = await placeOrder(
    quantityOfTsla,
    orderType
  );

  if (responseStatus == 500) {
    console.log(`Order placement failed with status: ${responseStatus}`);
    return Functions.encodeUint256(500);
  }

  if (responseStatus != 200) {
    console.log(`Order placement failed with status: ${responseStatus}`);
    return Functions.encodeUint256(3);
  }

  if (orderStatus !== "accepted") {
    console.log(`Order not accepted. Status: ${orderStatus}`);
    return Functions.encodeUint256(1);
  }

  let filled = await waitForOrderToFill(client_order_id);
  if (!filled) {
    console.log("Order was not filled within timeout period");
    // await cancelOrder(client_order_id);
    return Functions.encodeUint256(2);
  }

  return Functions.encodeUint256(quantityOfTsla);
}

async function placeOrder(qty, side) {
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
    },
  });

  const response = await alpacaRequest;

  const responseStatus = response.status;

  console.log(`\n Response Status ${responseStatus}`);
  console.log(response);
  console.log(`\n`);

  const { client_order_id, status: orderStatus } = response.data;

  return [client_order_id, orderStatus, responseStatus];
}

async function waitForOrderToFill(client_order_id) {
  let numberOfSleeps = 0;
  const capNumberOfSleeps = 10;
  let filled = false;

  while (numberOfSleeps < capNumberOfSleeps) {
    try {
      const alpacaRequest = await Functions.makeHttpRequest({
        method: `GET`,
        url: `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
        headers: {
          accept: "application/json",
          "APCA-API-KEY-ID": secrets.alpacaKey,
          "APCA-API-SECRET-KEY": secrets.alpacaSecret,
        },
      });

      const response = await alpacaRequest;

      const responseStatus = response.status;

      console.log(`Order status check - Response Status: ${responseStatus}`);

      if (responseStatus !== 200) {
        console.error(`Failed to get order status: ${responseStatus}`);
        return false;
      }

      // Add null/undefined checks
      if (!response.data) {
        console.error("Response data is undefined in order status check");
        return false;
      }

      const { status: orderStatus } = response.data;
      console.log(`Order status: ${orderStatus}`);

      if (orderStatus === "filled") {
        filled = true;
        break;
      }

      numberOfSleeps++;
      await sleep(SLEEP_TIME);
    } catch (error) {
      console.error("Error checking order status:", error);
      return false;
    }
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
