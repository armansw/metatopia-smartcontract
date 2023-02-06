# MetaTopia

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

# How to deploy
Try running some of the following tasks to deploy:

First, install node packages using yarn.

```zsh
$ yarn
```

- Fill all fields in .env.sample and rename it as .env

There are 4 contracts must be deployed and deploy order must be kept as following.

## 1. deploy TOPIA.sol
```zsh
$ yarn deploy:topia
```
// Here console will show deployed topia address, Replace TOPIA_ADDR at env with it.

## 2. deploy BullTraits.sol
```zsh
$ yarn deploy:trait
```
// Here console will show deployed BullTraits address, Replace BULLTRAIT_ADDR at env with it.

## 3. deploy Bull.sol

```zsh
$ yarn deploy:bull
```
// Here console will show deployed Bull address, Replace BULL_ADDR at env with it.

## 4. deploy Pool.sol

```zsh
$ yarn deploy:pool
```
// Here console will show deployed Pool address, Replace POOL_ADDR at env with it.