token=$(cat /etc/gitlab-runner/token)
curl --request DELETE "${runner_url}/api/v4/runners" --form "token=$token"
rm -rf /etc/gitlab-runner/token