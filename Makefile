# 사용 전 `source env.sh` 로 필수 환경변수를 설정한다. (env.example.sh 참고)
.PHONY: deps lint syntax test ping check apply

deps:
	# pipx로 설치한 ansible은 컬렉션을 번들로 포함해 "이미 설치됨"으로 건너뛴다.
	# Molecule은 별도 venv라 번들을 못 보므로 사용자 경로에 --force로 직접 설치한다.
	ansible-galaxy collection install -r requirements.yml -p ~/.ansible/collections --force

lint:
	ansible-lint

syntax:
	ansible-playbook site.yml --syntax-check

# Docker가 실행 중이어야 한다. create -> converge -> idempotence -> verify -> destroy
test:
	molecule test

ping:
	ansible all -m ping

check:
	ansible-playbook site.yml --check --diff

apply:
	ansible-playbook site.yml
