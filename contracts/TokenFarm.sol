//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // tokenAddress => (userAddress => Bbalance)
    mapping(address => mapping(address => uint256)) public stakingBalance;
    // se utiliza para saber cuantos tokens con balance > 0 tiene la cuenta
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMapping;
    // todo: sacar del mapping una vez que saca todo el balance
    // necesito que sea array ya que tengo que recorrerlo en issueTokens
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public dappToken;

    // creo el constructor para saber cual es la direccion del token reward
    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
        // TODO: could also update stakers array, to remove the user if they no longer have anything staked. But it's not a problem since in issueTokens we check if the user has any tokens staked
    }

    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount must be more than 0");
        require(tokenIsAllowed(_token), "Token is currenttly not allowed");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        bool addedUniqueToken = updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        /**
         * agrego a la lista de stakers si solo tiene un token,
         * porque está ingresando por primera vez
         */
        if (addedUniqueToken && uniqueTokensStaked[msg.sender] == 1) {
            // this was the f irst unique token staked for the user
            stakers.push(msg.sender);
        }
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
            return false;
        }
    }

    /**
     * Si stakingBalance[_token][_user] = 0 significa que en algun momento
     * quitó los fondos de ese token
     */
    function updateUniqueTokensStaked(address _user, address _token)
        internal
        returns (bool)
    {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
            return true;
        }
        return false;
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

    /**
     * Devuelve el valor en tokens que el usuario tiene acumulado en
     * todos los stakes
     */
    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleTokenValue(
                    _user,
                    allowedTokens[allowedTokensIndex]
                );
        }

        return totalValue;
    }

    /**
     * - Devuelve el valor en tokens que el usuario tiene acumulado en ese token
     * - 1 dappToken = 1 DAI
     * - price of the token * stakingBalance of de user
     */
    function getUserSingleTokenValue(address _user, address _token)
        public
        view
        returns (uint256)
    {
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        // 10 DAI * 1 / 10 ^^ 0 = 10 dappTokens
        return ((stakingBalance[_token][_user] * price) / (10**decimals));
    }

    /**
     * Cunsulta el precio del token en priceFeed para luego calcular la cantidad
     * de dappToken
     */
    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    /**
     * ============================================
     * ============================================
     * Solo el owner puede llamar estas funciones
     */

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }
}
