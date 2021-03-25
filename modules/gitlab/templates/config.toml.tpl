concurrent = 16
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "${runner_name}"
  url = "${runner_url}"
  token = "__REPLACED_BY_USER_DATA__"
  executor = "docker"
  environment = ["DOCKER_TLS_CERTDIR=", "DOCKER_DRIVER=overlay2"]
  output_limit = 52428800
  [runners.docker]
    tls_verify = false
    image = "busybox"
    privileged = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0  