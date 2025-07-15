if (secrets.alpacaKey == "" || secrets.alpacaSecret == "") {
  throw Error("Alpaca key or secrets not avail");
}

const symbol_or_asset_id = "TSLA";

const alpacaRequest = Functions.makeHttpRequest({
  url: `https://paper-api.alpaca.markets/v2/positions/${symbol_or_asset_id}`,
  headers: {
    accept: "application/json",
    "APCA-API-KEY-ID": secrets.alpacaKey,
    "APCA-API-SECRET-KEY": secrets.alpacaSecret,
  },
});

const [response] = await Promise.all([alpacaRequest]);

const tslaBalance = response.data.qty;

console.log(`TSLA Balance $${tslaBalance}`);

return Functions.encodeUint256(Math.round(tslaBalance * 1000000000000000000));
