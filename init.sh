#!/bin/bash

COGNITO_REGION=ap-northeast-1
COGNITO_ACCOUNT=110279172759
COGNITO_CLIENT_ID=50f88cjq1v496r3smgn3hgmqju
COGNITO_IDPOOL_ID=ap-northeast-1:f8c27fb5-2d2a-47c9-ac8c-7367523165e8
COGNITO_USERPOOL_ID=ap-northeast-1_lvFlQ6bMC
ECR_REPO=110279172759.dkr.ecr.ap-northeast-1.amazonaws.com

export DEBIAN_FRONTEND=noninteractive

sudo apt update
sudo apt install -y net-tools unzip golang-go python3-pip jq
sudo pip install yq

# swap file
if [ -f /var/swap/swapfile ]; then
  sudo mkdir -p /var/swap
  sudo dd if=/dev/zero of=/var/swap/swapfile bs=1M count=1024
  sudo chmod 600 /var/swap/swapfile
  sudo mkswap /var/swap/swapfile
  sudo swapon /var/swap/swapfile
  sudo cp -p /etc/fstab /etc/fstab.org
  echo -e "/var/swap/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
fi

# docker
if [ ! -x /usr/bin/docker ]; then
  sudo apt install -y  apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
fi
sudo systemctl enable docker

# AWS CLI v2
if [ ! -x /usr/local/bin/aws ]; then
  cd /tmp
  curl https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o awscliv2.zip
  unzip awscliv2.zip
  sudo ./aws/install
fi

# AWS ECR helper
if [ ! -x /usr/bin/docker-credential-ecr-login ]; then
  sudo apt install amazon-ecr-credential-helper
fi
if [ ! -x /usr/local/bin/cognito ]; then
  cd /tmp
  git clone https://github.com/jicowan/cognito.git
  cd cognito
  sed -i \
    -e 's/ClientId\s*string\s*=\s*".*"/ClientId string = "'${COGNITO_CLIENT_ID}'"/' \
    -e 's/Region\s*string\s*=\s*".*"/Region string = "'${COGNITO_REGION}'"/' \
    -e 's/AccountId\s*string\s*=\s*".*"/AccountId string = "'${COGNITO_ACCOUNT}'"/' \
    -e 's/IdentityPoolId\s*=\s*".*"/IdentityPoolId = "'${COGNITO_IDPOOL_ID}'"/' \
    -e 's/UserPoolId\s*=\s*".*"/UserPoolId = "'${COGNITO_USERPOOL_ID}'"/' \
    -e 's/us-west-2/'${COGNITO_REGION}'/' \
    main.go

  GOOS=linux GOARCH=arm64 go build -o cognito
  sudo cp ./cognito /usr/local/bin
fi

# cockpit
if [ "$(sudo systemctl is-active cockpit)" != "active" ]; then
  sudo apt install -y cockpit
fi

# user cameleo
id cameleo >/dev/null 2>&1
if [ $? -ne 0 ]; then
  sudo useradd -m -s /bin/bash -G docker cameleo
fi
if [ ! -f /home/cameleo/.docker/config.json ]; then
  sudo mkdir -p  /home/cameleo/.docker
  cat << EOF | sudo tee /home/cameleo/.docker/config.json > /dev/null
{
  "credsStore": "ecr-login",
  "credHelpers": {
    "public.ecr.aws": "ecr-login",
    "${ECR_REPO}": "ecr-login"
  }
}
EOF
  sudo find /home/cameleo/ -exec chown cameleo:cameleo {} \;
fi

# vimrc
if [ ! -f /root/.vimrc ]; then
  cat << EOF | suto tee /root/.vimrc > /dev/null
set expandtab
set softtabstop=2
set shiftwidth=2
set autoindent
EOF
fi
 
