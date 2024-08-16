// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../utils/MarketSpec.sol";
import "../utils/ZgInitializable.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FixedPrice is IMarket, ZgInitializable, AccessControlEnumerable, ReentrancyGuard {
    // Reserved storage slots for future upgrades
    uint[50] private __gap;

    // Roles
    bytes32 public constant PARAMS_ADMIN_ROLE = keccak256("PARAMS_ADMIN_ROLE");

    // State variables
    uint public pricePerSector;
    address public flow;
    address public reward;

    // Events
    event PricePerSectorUpdated(uint oldPrice, uint newPrice);
    event FeeCharged(address indexed sender, uint beforeLength, uint uploadSectors, uint paddingSectors, uint feeCharged);

    // Initialization function (can only be called once)
    function initialize(uint pricePerSector_, address flow_, address reward_) public onlyInitializeOnce {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PARAMS_ADMIN_ROLE, _msgSender());

        pricePerSector = pricePerSector_;
        flow = flow_;
        reward = reward_;
    }

    // Function to update the price per sector (only callable by PARAMS_ADMIN_ROLE)
    function setPricePerSector(uint pricePerSector_) external onlyRole(PARAMS_ADMIN_ROLE) {
        emit PricePerSectorUpdated(pricePerSector, pricePerSector_);
        pricePerSector = pricePerSector_;
    }

    // Function to charge fees based on the number of sectors
    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external nonReentrant {
        require(_msgSender() == flow, "FixedPrice: Unauthorized sender");

        uint totalSectors = uploadSectors + paddingSectors;
        uint baseFee = pricePerSector * uploadSectors;
        require(baseFee <= address(this).balance, "FixedPrice: Insufficient balance to cover the fee");
        
        uint bonus = address(this).balance - baseFee;
        uint paddingPart = (baseFee * paddingSectors) / totalSectors;
        uint uploadPart = baseFee - paddingPart;

        if (paddingSectors > 0) {
            IReward(reward).fillReward{value: paddingPart}(beforeLength, paddingSectors);
        }

        IReward(reward).fillReward{value: bonus + uploadPart}(beforeLength + paddingSectors, uploadSectors);

        emit FeeCharged(_msgSender(), beforeLength, uploadSectors, paddingSectors, baseFee);
    }

    // Fallback function to receive Ether
    receive() external payable {}
}
