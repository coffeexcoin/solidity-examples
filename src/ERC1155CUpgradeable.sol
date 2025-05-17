// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1155} from "solady-0.1.18/src/tokens/ext/zksync/ERC1155.sol";
import {ERC2981} from "solady-0.1.18/src/tokens/ERC2981.sol";
import {Ownable} from "solady-0.1.18/src/auth/Ownable.sol";
import {UUPSUpgradeable} from "solady-0.1.18/src/utils/UUPSUpgradeable.sol";
import {ICreatorToken} from "limitbreakinc-creator-token-standards-5.0.0/src/interfaces/ICreatorToken.sol";
import {ITransferValidator} from "limitbreakinc-creator-token-standards-5.0.0/src/interfaces/ITransferValidator.sol";

/// @title ERC1155CUpgradeable
/// @notice An example of an upgradeable ERC1155C contract that implements using zksync safe 1155 base
/// @author @coffeexcoin (https://x.com/coffeexcoin)
contract ERC1155CUpgradeable is ERC1155, ERC2981, Ownable, UUPSUpgradeable, ICreatorToken {
    address private _transferValidator;

    constructor() {
        _initializeOwner(msg.sender);
        _setDefaultRoyalty(msg.sender, 500);
        // default creator token transfer validator (v5)
        // https://apptokens.com/docs/integration-guide/creator-token-standards/v5/contract-deployments
        _transferValidator = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    }

    function uri(uint256) public pure override returns (string memory) {
        // replace with your own token URI logic
        return "";
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC2981) returns (bool) {
        return ERC1155.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /* Creator Token Interface */

    function getTransferValidator() external view returns (address) {
        return _transferValidator;
    }

    function setTransferValidator(address newTransferValidator) external onlyOwner {
        emit TransferValidatorUpdated(_transferValidator, newTransferValidator);
        _transferValidator = newTransferValidator;
    }

    /// @dev returns the function signature for the transfer validation function and whether it is a view function
    /// 1155 validator function is not view, 0x1854b241 is the selector for the function
    /// validateTransfer(address caller, address from, address to, uint256 tokenId, uint256 amount) 
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = 0x1854b241;
        isViewFunction = false;
    }

    /// @dev solady ERC1155 requires that this function is overridden to return true when using a _beforeTokenTransfer hook
    function _useBeforeTokenTransfer() internal pure override returns (bool) {
        return true;
    }

    /// @dev before token transfer hook to apply ERC1155C transfer validation
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory // data
    ) internal override {
        // don't validate transfers for burns or mints
        if (from == address(0) || to == address(0)) {
            return;
        }

        // apply transfer validation if the transfer validator is set
        if (_transferValidator != address(0)) {
            uint256 length = ids.length;
            if (length != amounts.length) {
                revert ArrayLengthsMismatch();
            }
            for (uint256 i; i < length; i++) {
                ITransferValidator(_transferValidator).validateTransfer(msg.sender, from, to, ids[i], amounts[i]);
            }
        }
    }
}
