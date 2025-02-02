# syntax=docker/dockerfile:1

# note: this docker file assumes you already have komodod instance running outside of this container
# make sure to change line 55 to your remote komodod api address
# alternatively use the following set of commands to download pre-built binaries and create OCCS daemon startup script

# RUN wget https://raw.githubusercontent.com/KomodoPlatform/komodo/master/zcutil/fetch-params.sh
# RUN chmod +x fetch-params.sh
# RUN ./fetch-params.sh
# RUN wget https://github.com/KomodoPlatform/komodo/releases/download/v0.8.1/komodo_0.8.1_linux.zip
# RUN unzip komodo_0.8.1_linux.zip
# RUN echo 'nohup ./komodod -ac_name=OCCS -pubkey=038afbc819aecfb3d65acdf270f755c9279d69d4a27293f10889264b8bd6c1fae2 -ac_pubkey=038afbc819aecfb3d65acdf270f755c9279d69d4a27293f10889264b8bd6c1fae2 -ac_founders=1000 -ac_founders_reward=5000000000000 -ac_cc=2 -ac_adaptivepow=1 -ac_staked=95 -ac_reward=25000 -ac_supply=500000000 -addnode=162.55.144.64 -addnode=162.55.144.56 &' >> start-occs-daemon.sh
# RUN chmod +x start-occs-daemon.sh

# set the base image to Debian
# https://hub.docker.com/_/debian/
FROM debian:latest

# replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# update the repository sources list
# and install dependencies
RUN apt-get update && apt-get install -y git curl libzmq3-dev make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev clang

# use pyenv to install old python version 3.5 for node 8
RUN git clone --depth=1 https://github.com/pyenv/pyenv.git .pyenv
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${PATH}"
RUN CC=clang pyenv install 3.5

RUN eval "$(pyenv init -)"
RUN pyenv global 3.5

# nvm environment variables
ENV NVM_DIR /usr/local/nvm
# this is the only version that compiles zmq bindings using python 3.5
# all other versions below and up fail to compile zmq :(
ENV NODE_VERSION 8.17.0

# install nvm
# https://github.com/creationix/nvm#install-script
RUN curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash

# install node and npm
RUN source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION

# add node and npm to path so the commands are available
ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# confirm installation
RUN node -v
RUN npm -v

WORKDIR .

RUN git clone https://github.com/Open-Food-Chain/insight-oracles-api
WORKDIR insight-oracles-api

RUN npm install git+https://git@github.com/pbca26/bitcore-node-komodo

RUN ./node_modules/bitcore-node-komodo/bin/bitcore-node create oracle-explorer
RUN cd oracle-explorer && .././node_modules/bitcore-node-komodo/bin/bitcore-node install git+https://git@github.com/pbca26/insight-api-komodo git+https://git@github.com/pbca26/insight-ui-komodo

RUN cp deps/bitcore-node-komodo/lib/services/bitcoind.js oracle-explorer/node_modules/bitcore-node-komodo/lib/services
RUN cp deps/bitcoind-rpc/lib/index.js oracle-explorer/node_modules/bitcoind-rpc/lib
RUN cp deps/insight-api-komodo/lib/index.js oracle-explorer/node_modules/insight-api-komodo/lib
RUN cp deps/insight-api-komodo/lib/oracles.js oracle-explorer/node_modules/insight-api-komodo/lib
RUN cp -r deps/insight-ui-komodo oracle-explorer/node_modules/
