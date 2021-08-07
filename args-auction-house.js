// eslint-disable-next-line @typescript-eslint/no-var-requires
require("dotenv").config();

const WETH_ADDRESS =
  process.env.WETH_ADDRES || "0xc778417e063141139fce010982780140aa0cd5ab"; // Rinkeby WETH address
const SERVICE_CUT = Number(process.env.SERVICE_CUT || 1000);
const INITIAL_CUT = Number(process.env.INITIAL_CUT || 1000);
const NATIVE_USED = Boolean(process.env.NATIVE_USED || true); // Set this to false if we deploy to Polygon etc.

module.exports = [SERVICE_CUT, INITIAL_CUT, WETH_ADDRESS, NATIVE_USED];
