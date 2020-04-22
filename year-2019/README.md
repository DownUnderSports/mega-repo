# Rails 5.2 Dev Setup

## Geeting Started

* install `yarn`, `stylus`, `nib` and `react-scripts`:
  - `sudo npm install -g yarn stylus nib react-scripts`

* create and seed the db:
  - `bin/setup`

* setup env files (especially client folder env files):
  - `bin/base_env_files`

* install local JS packages:
  - `cd client && yarn && cd ..`

### to start the admin app in development:  `./admin-servers`
### to start the client app in development: `./client-servers`
### to run the production app locally:      `./start-servers`

## Production Credentails

* to edit production credentials, you first need the master key. If you don't have it please ask another dev. DO NOT RUN WITHOUT `master.key`
  - `rails:credentials:edit`
