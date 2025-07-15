// const quantityOfTsla = args[0];
// const orderType = "sell"; //buy/sell


// Return 0 on unsuccessful sell 


const SLEEP_TIME = 5000 // 5 seconds


async function main() {
  const quantityOfTsla = "2";
  const orderType = args[1]; //buy/sell
  _checkKeys();


}
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
    side: `${orderType}`,
    symbol: "TSLA",
    qty: `${quantityOfTsla}`,
  },
});

// const [response] = await Promise.all([alpacaRequest]);
const response = await alpacaRequest;

// const amountOfTslaBought = response.data.filled_qty;
// const avgPriceBoughtAt = response.data.filled_avg_price;

const filledQty = response.data.qty; // "1"

// Parse string to number, scale to 1e18, convert to BigInt
const scaledQty = BigInt(filledQty) * 10n ** 18n;

// Encode as uint256
const encoded = Functions.encodeUint256(scaledQty);






// Return encoded Uint8Array
return encoded;
