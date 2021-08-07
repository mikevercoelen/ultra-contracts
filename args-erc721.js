// eslint-disable-next-line @typescript-eslint/no-var-requires
require("dotenv").config();

const BASE_TOKEN_URI =
  process.env.BASE_TOKEN_URI || "https://ultrareum.nft.com/";

module.exports = [BASE_TOKEN_URI];
