// test/PrivateQnA.test.ts
import { ethers } from "hardhat";
import { expect } from "chai";

import { Contract } from "ethers";

describe("PrivateQnA", function () {
  let qna: Contract;
  let token: Contract;
  let owner: any;
  let userA: any;
  let userB: any;
  let userC: any;

  beforeEach(async function () {
    [owner, userA, userB, userC] = await ethers.getSigners();

    // Deploy mock ERC20 token
    const Token = await ethers.getContractFactory("ERC20Mock");
    token = await Token.deploy("TestToken", "TTK", userA.address, ethers.utils.parseEther("1000"));
    await token.deployed();

    // Deploy QnA contract
    const QnA = await ethers.getContractFactory("PrivateQnA");
    qna = await QnA.deploy();
    await qna.deployed();
  });

  it("should allow A to ask, B to reply, and C to arbitrate", async function () {
    // A approve QnA to spend 100 tokens
    await token.connect(userA).approve(qna.address, ethers.utils.parseEther("100"));

    // A asks question with reward
    await qna.connect(userA).askQuestionWithReward("cipher:hello?", token.address, ethers.utils.parseEther("100"));

    // Simulate deliver (FHE external value bypassed in test)
    await qna.connect(userB).tryDeliverQuestion(0, 0, "0x");

    // B accepts
    await qna.connect(userB).acceptQuestion(0);

    // B replies
    await qna.connect(userB).replyToQuestion(0, "cipher:hello A");

    // A checks reply
    const reply = await qna.connect(userA).getEncryptedReply(0);
    expect(reply).to.equal("cipher:hello A");

    // A is unhappy -> files dispute
    await qna.connect(userA).fileDispute(0);

    // C arbitrates in favor of A
    await qna.connect(userC).arbitrateDispute(0, true);

    const ABalance = await token.balanceOf(userA.address);
    const BBalance = await token.balanceOf(userB.address);
    const CBalance = await token.balanceOf(userC.address);

    expect(ABalance).to.equal(ethers.utils.parseEther("990")); // got 90 back
    expect(BBalance).to.equal(ethers.utils.parseEther("0"));
    expect(CBalance).to.equal(ethers.utils.parseEther("10"));
  });

  it("should reward B if dispute fails for A", async function () {
    await token.connect(userA).approve(qna.address, ethers.utils.parseEther("100"));
    await qna.connect(userA).askQuestionWithReward("cipher:another?", token.address, ethers.utils.parseEther("100"));

    await qna.connect(userB).tryDeliverQuestion(0, 0, "0x");
    await qna.connect(userB).acceptQuestion(0);
    await qna.connect(userB).replyToQuestion(0, "cipher:ok");
    await qna.connect(userA).fileDispute(0);

    // C rules for B (A loses)
    await qna.connect(userC).arbitrateDispute(0, false);

    const ABalance = await token.balanceOf(userA.address);
    const BBalance = await token.balanceOf(userB.address);
    const CBalance = await token.balanceOf(userC.address);

    expect(ABalance).to.equal(ethers.utils.parseEther("900")); // lost 90
    expect(BBalance).to.equal(ethers.utils.parseEther("90"));
    expect(CBalance).to.equal(ethers.utils.parseEther("10"));
  });
});