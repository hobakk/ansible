# 사용법: cp env.example.sh env.sh 후 값을 채우고 `source env.sh`
# env.sh 는 .gitignore 대상이다. 실제 값을 이 예시 파일에 쓰지 않는다.
export ANSIBLE_SSH_KEY_FILE=~/.ssh/ansible
export ALLOWED_SUBNET=10.0.0.0/24
export ALLOWED_PUBLIC_IP=203.0.113.10
# 해시에는 $ 가 있으므로 반드시 작은따옴표로 감싼다. 생성: openssl passwd -6
export DEPLOY_PASSWORD_HASH='$6$replace$with-your-own-hash'
export DEPLOY_SSH_PUBKEY="$(cat ~/.ssh/ansible.pub)"
export KMJ_SSH_PUBKEY="$(cat ~/.ssh/ansible.pub)"
