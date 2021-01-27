#!/bin/sh

PREFIX=$1
NODES=$2
MACHINE_TYPE=$3
CORES_PER_NODE=$4
echo PREFIX=$PREFIX NODES=$NODES MACHINE_TYPE=$MACHINE_TYPE CORES_PER_NODE=$CORES_PER_NODE

curl -O -L https://github.com/hpc/charliecloud/releases/download/v0.21/charliecloud-0.21.tar.gz
tar -xvf charliecloud-0.21.tar.gz
cd charliecloud-0.21
./configure --prefix=/usr
make
sudo make install
# Pull in BEE code and dependencies
curl -O -L https://tronserv.net/bee/BEE_Private-2021-01-27.tar.xz
tar -xvf BEE_Private-2021-01-27.tar.xz
cd BEE_Private-2021-01-27

curl -O -L https://tronserv.net/bee/neo4j-3.5.17-env.tar.gz
# Install gdown for downloading files from Google Drive
python3 -m venv venv
. ./venv/bin/activate
pip install gdown
gdown https://drive.google.com/uc?id=1IzcVg_R10K2mgZC0F2fzwfke_D16Aun2
mv cjy7117.flecsale-ubuntu_mpi_master.tar.gz cjy7117.flecsale.tar.gz

# Generate the right config
export CWD=$(pwd)
mkdir -p ~/.config/beeflow
curl -O -L https://tronserv.net/bee/bee.conf
python gen-conf.py $(pwd) $PREFIX $NODES $MACHINE_TYPE $CORES_PER_NODE \
	> ~/.config/beeflow/bee.conf

# Get the proper Google Keyfile
echo $GCLOUD_KEYFILE_JSON | base64 -d > google.json
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/google.json

python3 -m venv venv
. ./venv/bin/activate
pip install --upgrade pip
pip install poetry
poetry install

# Start scheduler and BEEStart
python bin/BEEStart --gdb
python beeflow/scheduler/scheduler.py &

# Generate keyfile
python beeflow/common/worker/cloud/ssh_keygen.py bee_key
          
python beeflow/task_manager/task_manager.py &
# Wait for cloud set up
sleep 1650
python beeflow/wfm/wfm.py &

# Wait for the workflow manager to start up
sleep 100

# Start the workflow
python beeflow/client/client-cli.py ~/.config/beeflow/bee.conf submit 42 flecsale.cwl
python beeflow/client/client-cli.py ~/.config/beeflow/bee.conf start 42

# Wait for the workflow to complete
sleep 120
