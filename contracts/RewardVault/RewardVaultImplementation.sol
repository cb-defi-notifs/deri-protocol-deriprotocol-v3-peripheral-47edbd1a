// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import '../token/IERC20.sol';
import '../token/IDToken.sol';
import '../pool/IPool.sol';
import '../library/SafeMath.sol';
import './RewardVaultStorage.sol';

contract RewardVaultImplementation is RewardVaultStorage {

	using SafeMath for uint256;
	using SafeMath for int256;
	uint256 constant UONE = 1e18;

	IERC20 public immutable RewardToken;
	IPool public immutable Pool; // the pool
	IDToken public immutable LToken;

	event SetRewardPerSecond(uint256 newRewardPerSecond);
	event Claim(address account, uint256 tokenId, uint256 amount);

	constructor(uint256 startTimestamp, address _rewardToken, address _pool, address _lToken) {
		lastRewardTimestamp = startTimestamp;
		RewardToken = IERC20(_rewardToken);
		Pool = IPool(_pool);
		LToken = IDToken(_lToken);
	}

	//  ========== ADMIN ==============
	function setRewardPerSecond(uint256 _rewardPerSecond) _onlyAdmin_ external {
		_updateAccRewardPerLiquidity(Pool.liquidity().itou());
		rewardPerSecond = _rewardPerSecond;
		emit SetRewardPerSecond(_rewardPerSecond);
	}

	function emergencyWithdraw() _onlyAdmin_ external {
		uint256 balance = RewardToken.balanceOf(address(this));
		RewardToken.transfer(msg.sender, balance);
	}

	// ============= UPDATE =================
	function updateVault(uint256 totalLiquidity, uint256 tokenId, uint256 liquidity) external {
		require(msg.sender == address(Pool), "Only authorized by pools");
		// update accRewardPerLiquidity before adding new liquidity
		_updateAccRewardPerLiquidity(totalLiquidity);

		// settle reward to the user before updating new liquidity
		UserInfo storage user = userInfo[tokenId];
		user.unclaimed += liquidity * (accRewardPerLiquidity - user.accRewardPerLiquidity) / UONE;
		user.accRewardPerLiquidity = accRewardPerLiquidity;
	}

	function claim() external {
		_updateAccRewardPerLiquidity(Pool.liquidity().itou());

		require(LToken.exists(msg.sender), "LToken not exist");
		uint256 tokenId = LToken.getTokenIdOf(msg.sender);
		UserInfo storage user = userInfo[tokenId];
		IPool.LpInfo memory info = Pool.lpInfos(tokenId);
		uint256 liquidity = info.liquidity.itou();
		uint256 claimed = user.unclaimed + liquidity * (accRewardPerLiquidity - user.accRewardPerLiquidity) / UONE;

		user.accRewardPerLiquidity = accRewardPerLiquidity;
		user.unclaimed = 0;

		RewardToken.transfer(msg.sender, claimed);
		emit Claim(msg.sender, tokenId, claimed);
	}

	function _updateAccRewardPerLiquidity(uint256 totalLiquidity) internal {
		uint256 reward = (block.timestamp - lastRewardTimestamp) * rewardPerSecond;
		if (totalLiquidity > 0) {
			accRewardPerLiquidity += reward * UONE / totalLiquidity;
		}
		lastRewardTimestamp = block.timestamp;
	}


	// ============= VIEW ===================
	function pending(address account) external view returns (uint256) {
		uint256 tokenId = LToken.getTokenIdOf(account);
		return pending(tokenId);
	}

	function pending(uint256 tokenId) public view returns (uint256) {
		UserInfo memory user = userInfo[tokenId];
		uint256 reward = (block.timestamp - lastRewardTimestamp) * rewardPerSecond;
		uint256 totalLiquidity = Pool.liquidity().itou();
		uint256 newAccRewardPerLiquidity = accRewardPerLiquidity;
		if (totalLiquidity > 0) {
			newAccRewardPerLiquidity += reward * UONE / totalLiquidity;
		}

		IPool.LpInfo memory info = Pool.lpInfos(tokenId);
		uint256 liquidity = info.liquidity.itou();
		return user.unclaimed + liquidity * (newAccRewardPerLiquidity - user.accRewardPerLiquidity) / UONE;
	}

}
