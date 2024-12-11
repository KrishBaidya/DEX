import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Router", (m) => {
  const apollo = m.contract("ExchangeRouter", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]);

  return { apollo };
});