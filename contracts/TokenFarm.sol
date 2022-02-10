//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenFarm is Ownable {
    // tokenAddress => (userAddress => Bbalance)
    mapping(address => mapping(address => uint256)) public stakingBalance;
    // se utiliza para saber cuantos tokens con balance > 0 tiene la cuenta
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => bool) public allowedTokens;
    // todo: sacar del mapping una vez que saca todo el balance
    // necesito que sea array ya que tengo que recorrerlo en issueTokens
    address[] public stakers;

    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount must be more than 0");
        require(tokenIsAllowed(_token), "Token is currenttly not allowed");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        /**
         * agrego a la lista de stakers si solo tiene un token,
         * porque está ingresando por primera vez
         */
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        if (allowedTokens[_token] == true) {
            return true;
        }
        return false;
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens[_token] = true;
    }

    /**
     * Si stakingBalance[_token][_user] = 0 significa que en algun momento
     * quitó los fondos de ese token
     */
    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    function issueToken() public onlyOwner {
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            // send them a token reward
            // based on their total value locked
            dappToken.transfer(recipient, userTotalValue);
        }
    }
}
