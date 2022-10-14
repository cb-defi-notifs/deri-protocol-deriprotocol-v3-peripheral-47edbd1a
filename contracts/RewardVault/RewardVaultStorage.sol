// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../utils/Admin.sol';

contract RewardVaultStorage is Admin {

	address public implementation;

	struct UserInfo {
		uint256 accRewardPerLiquidity; // last updated accRewardPerLiquidity when the user triggered claim/update ops
		uint256 unclaimed; // the unclaimed reward
		//
		// We do some math here. Basically, any point in time, the amount of reward token
		// entitled to a user but is pending to be distributed is:
		//
		//  pending reward = lpLiquidity * (accRewardPerLiquidity - user.accRewardPerLiquidity)
		//  claimable reward = pending reward + user.unclaimed;
		//
		// Whenever a user add or remove liquidity to a pool. Here's what happens:
		//   1. The pool's `accRewardPerLiquidity` (and `lastRewardBlock`) gets updated.
		//   2. the pending reward moved to user.unclaimed.
		//   3. User's `accRewardPerLiquidity` gets updated.
	}

	mapping(uint256 => UserInfo) public userInfo;

	uint256 public rewardPerSecond; // How many reward token per block.

	uint256 public lastRewardTimestamp; // Last updated timestamp when any user triggered claim/update ops.

	uint256 public accRewardPerLiquidity; // Accumulated reward per share.

	event NewImplementation(address newImplementation);

}
