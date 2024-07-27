use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

#[starknet::interface]
trait IDeployWallet<TContractState> {
    fn deploy_wallet(ref self: TContractState, salt: felt252, public_key: felt252) -> ContractAddress;
    fn withdraw(ref self: TContractState);
}

#[starknet::contract]
mod DeployWallet {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{get_caller_address, get_contract_address, deploy_syscall, ClassHash};
    use super::{ContractAddress, IDeployWallet};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    const ETH_CONTRACT_ADDRESS: felt252 = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        WalletDeployed: WalletDeployed,
    }

    #[derive(Drop, starknet::Event)]
    struct WalletDeployed {
        wallet_address: ContractAddress,
        public_key: felt252,
    }

    #[storage]
    struct Storage {
        eth_token: IERC20CamelDispatcher,
        wallet_class_hash: ClassHash,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, wallet_class_hash: ClassHash) {
        let eth_contract_address = ETH_CONTRACT_ADDRESS.try_into().unwrap();
        self.eth_token.write(IERC20CamelDispatcher { contract_address: eth_contract_address });
        self.wallet_class_hash.write(wallet_class_hash);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl DeployWalletImpl of IDeployWallet<ContractState> {
        fn deploy_wallet(ref self: ContractState, salt: felt252, public_key: felt252) -> ContractAddress {
            // Prepare constructor calldata for the wallet
            let mut calldata = array![public_key];

            // Deploy the wallet contract
            let (wallet_address, _) = deploy_syscall(
                self.wallet_class_hash.read(),
                salt,
                calldata.span(),
                false
            ).unwrap();

            // Emit an event
            self.emit(WalletDeployed { wallet_address, public_key });

            wallet_address
        }

        fn withdraw(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let balance = self.eth_token.read().balanceOf(get_contract_address());
            self.eth_token.read().transfer(self.ownable.owner(), balance);
        }
    }
}
