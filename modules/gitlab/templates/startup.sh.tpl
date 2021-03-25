sudo apt-get update

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    jq \
    software-properties-common

mkdir -p /etc/gitlab-runner
cat > /etc/gitlab-runner/config.toml <<- EOF

${runners_config}

EOF

token=$(curl --request POST -L "${runner_url}/api/v4/runners" \
    --form "token=${runner_registration_token}" \
    --form "tag_list=gcp,terraform" \
    --form "run_untagged=false" \
    | jq -r .token)

echo -n $token > /etc/gitlab-runner/token

sed -i.bak s/__REPLACED_BY_USER_DATA__/`echo $token`/g /etc/gitlab-runner/config.toml

curl -L https://dl.google.com/cloudagents/install-logging-agent.sh | sudo bash

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get -y install gitlab-runner