import { createWalletClient, http, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { hardhat, arbitrumSepolia } from "viem/chains";

// Replace with your private key
const PRIVATE_KEY =
  "0x5606305be272e5e2edf874d700e0d95a9613a0db1e7d4b9b2b13bd50dfd7044f";
console.log(PRIVATE_KEY);

async function main() {
  // List of recipient addresses
  const recipients = [
    "0xA5e9aC910d6f8466C84a4d2836674b2E4bC7080E",
    "0x504961eAB5A99Cd37a3A1Dda1BBd1722890bcd2B",
    "0x5C71503917Db17F2e29fA9FA81C73f99c4D6568f",
    "0x15bceD95875eE6F9e3Fd5c7Add92E097e4Cd33cB",
    "0xE7D9b4e6B117d91e5a5D4744BBb5D1B76a0E4F48",
    "0xCf175eb11A4faE8dA527580949Ad42D8c0812dF7",
    "0xB4d6279B5eBf79C2D1d73B4f25eeBdaC6A4cC3e6",
    "0x094a4fcb7274c42a1729c8fbfcfde4f34041f94d",
    "0x35e8501e345Cdd4ff87Be1388F32c177BadBC332",
    "0x7BC006d0B4240A4E90A9450cBAB499BB41e092d8",
    "0xb5063F08Ed94547fD59De52Aafa4B51237687245",
    "0x99D5e6593d78400EA2ba59162e0e838F45234dd5",
    "0x76a792351e79a920b0CF67db3f881B61a06d4c38",
    "0xeA4F0D283fFaB5154B269Dcc0eb8ebd62B14D003",
    "0xAf28a4396D515b59d79AfbeC5fdb48F3CA7b56EB",
    "0xb8DB6089d89DCeb351C897794955B37012373e7e",
    "0x7F7fFc171cCcb1Cf39943722baD6eDf2Bc917566",
    "0x3f90DA75010565E1ad77964A555Ec2a5EeeA6410",
    "0x0Af85eaD6f83C72AcBAf1F2074AcbCAfAd02D40a",
    "0xfba11cd34ffF534099DF434ed3AbeD609baCd976",
    "0x13E4a1DD0B7C6957e54ba3DaE4895D2752d76f46",
    "0x2b279Ae7b98BF749620eE649428754F7bfA13aDC",
    "0x2c635C55d588E10A484A4583461cBb6b9F653E51",
    "0x66C730d761D36DFe7CA5D8f29D2CD882DfB8cC72",
    "0x1BA65e102D5A20A737D3Fec8b7a0F36651440B0f",
    "0x906f2C5f09814DDB75399431F974B65A772868dC",
    "0xdb154273036613c5ace12fae6e4291aa6ea993ba",
    "0x90E38a809d23F2559ce74018b106A3B35c085fF7",
    "0xf3AdAA592521A4601A4570a9Fe265264fc9eC982",
    "0x094a4fcb7274C42a1729C8FbfCFDe4F34041f94d",
  ];

  // Amount to send to each address (0.1 ETH)
  const amount = parseEther("0.01");

  // Create wallet client
  const account = privateKeyToAccount(PRIVATE_KEY);
  console.log(account);
  const client = createWalletClient({
    account,
    chain: arbitrumSepolia,
    transport: http(),
  });

  console.log("Starting ETH distribution...");

  // Send ETH to each address
  for (const recipient of recipients) {
    try {
      const hash = await client.sendTransaction({
        to: recipient as `0x${string}`,
        value: amount,
      });
      console.log(`Sent ${amount} ETH to ${recipient}`);
      console.log(`Transaction hash: ${hash}`);

      // Add 5 second delay
      await new Promise((resolve) => setTimeout(resolve, 5000));
    } catch (error) {
      console.error(`Failed to send ETH to ${recipient}:`, error);
    }
  }

  console.log("ETH distribution completed");
}

// Execute the script
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
