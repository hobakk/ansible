# ansible-server-baseline

**서버 2대의 초기 설정을 사람 손 없이, 몇 번을 돌려도 같은 결과로 만들어 주는 Ansible 프로젝트**

개발 서버(`dev`)와 GPU 서버(`gpu`)에 필요한 설정(패키지, 계정, SSH 보안, Docker, 방화벽, 감사 로그)을 코드로 정의하고, 자동 테스트와 정적 검사로 품질을 확인했습니다.

## 한눈에 보기

| 항목 | 결과 |
|---|---|
| 자동화한 서버 설정 | 8개 role (패키지, 유저, SSH 보안, Docker, 방화벽, 감사 로그, NVIDIA 드라이버, 로그인 안내) |
| 재실행 안전성 (멱등성) | 두 서버 모두 재실행 시 `changed=0` |
| 정적 검사 | `ansible-lint` **production** 프로필 통과 (0 failure, 0 warning) |
| 자동 테스트 | Molecule: 적용 → 재실행 변경 없음 → 결과 검증 전 과정 통과 |
| 보안 | root 로그인·비밀번호 로그인 차단, 서버별 최소 포트만 개방, 민감 파일 변경 감사 |
| 비밀값 관리 | 개인키·비밀번호 해시·공개키·허용 IP를 코드에 두지 않고 환경변수로 주입 |
| 실행 환경 | Multipass Ubuntu 24.04 VM 2대에서 실제 적용·검증 |

## 왜 만들었나

서버 설정을 사람이 직접 하면 서버마다 미묘하게 달라지고, 누가 무엇을 바꿨는지 알 수 없고, 같은 서버를 다시 만들기도 어렵습니다.
이 프로젝트는 그 설정을 코드로 옮겨 **같은 명령으로 같은 상태를 언제든 다시 만들 수 있게** 하는 것이 목표입니다.

서버 역할이 다르면 필요한 설정도 다릅니다. 두 서버가 공통 설정을 공유하되, 열어야 하는 포트만 서버별로 다르게 관리합니다.

| 서버 | 역할 | 추가로 여는 포트 |
|---|---|---|
| 공통 | - | 22 (SSH) |
| `dev` | 개발 서버 | 80, 443, 3306 (MySQL은 허용된 IP 대역에서만) |
| `gpu` | GPU 서버 | 5432 (PostgreSQL은 허용된 IP 대역에서만) |

## 무엇을 자동화했나

| role | 하는 일 | 쉽게 말하면 |
|---|---|---|
| `common` | 기본 패키지 설치 | 서버마다 필요한 기본 도구를 똑같이 깔아 둔다 |
| `users` | 계정 생성·삭제, SSH 공개키 등록, sudo 비밀번호 설정 | 누가 접속할 수 있는지를 코드로 관리한다 |
| `ssh` | root 로그인과 비밀번호 로그인 차단 | 열쇠(SSH 키)가 있는 사람만 들어올 수 있게 한다 |
| `docker` | Docker 공식 저장소로 설치, 계정을 docker 그룹에 추가 | 컨테이너를 돌릴 수 있는 기반을 만든다 |
| `ufw` | 방화벽 규칙 | 필요한 문만 열고 나머지는 닫는다 |
| `auditd` | 민감한 파일의 변경 기록 | "누가 언제 무엇을 바꿨는지" CCTV를 단다 |
| `nvidia` | GPU 서버에서 NVIDIA 드라이버 설치와 `nvidia-smi` 확인 | GPU가 실제로 있는 서버에서만 설치하고, 없으면 건너뛴다 |
| `motd` | 로그인 안내 문구 | 이 서버가 Ansible로 관리된다는 표시 |

## 검증 결과

Multipass Ubuntu 24.04 VM 2대(`dev`, `gpu`)에서 확인한 내용입니다.

| 확인한 것 | 결과 |
|---|---|
| 최초 적용 | 패키지, 유저, Docker, 방화벽, SSH 설정이 `changed`로 정상 적용 |
| 재실행 | 두 서버 모두 `changed=0` (이미 원하는 상태면 아무것도 바꾸지 않음) |
| 설정 파일을 일부러 삭제하고 재실행 | 지운 서버만 복구되고 `Reload sshd`가 실행됨. 다른 서버는 `changed=0` |
| 복구 후 재실행 | 두 서버 모두 `changed=0`, 재시작 동작은 실행되지 않음 |
| SSH 설정 (`sshd -T`) | `permitrootlogin no`, `passwordauthentication no`, `kbdinteractiveauthentication no`, `maxauthtries 3` |
| 권한 분리 | `deploy`는 `sudo -i` 성공, 일반 계정 `kmj`는 거부 |
| 감사 규칙 | `auditctl -l`에서 감시 규칙 8개 적재 확인 |
| 감사 기록 | `/etc/sudoers.d/`에 파일을 만들자 실행한 명령, 대상 경로, 로그인한 원 사용자(`auid=1000`)가 기록됨 |
| 필수 환경변수 누락 | 서버에 접속하기도 전에 사전 검증에서 실패 |
| `ansible-lint` | `production` 프로필 통과 (0 failure, 0 warning) |
| Molecule (`make test`) | 적용 `changed=3` → 재실행 `changed=0` → 검증 7개 task 통과 |

## 설계에서 신경 쓴 점

- **서버가 끊기지 않게**: 방화벽은 SSH 허용 규칙을 먼저 넣고 차단 정책을 켭니다. SSH 설정은 `sshd -t`로 문법을 먼저 검사해서 잘못된 설정은 배포되지 않습니다.
- **바뀐 것만 반영**: SSH 설정 파일이 실제로 바뀐 경우에만 `handler`가 sshd를 reload합니다. 바뀐 게 없으면 서비스를 건드리지 않습니다.
- **기존 설정을 덮어쓰지 않게**: `sshd_config` 본문을 고치지 않고 `sshd_config.d/00-hardening.conf`를 따로 둡니다. sshd는 먼저 읽은 값을 쓰기 때문에, 클라우드 이미지의 기본 설정(`50-cloud-init.conf`)보다 먼저 읽히도록 `00-`을 붙였습니다.
- **비밀값은 코드 밖으로**: 개인키 경로, 허용 IP, 공개키, 비밀번호 해시를 환경변수로 받습니다. 비밀번호는 평문이 아니라 해시만 다루고, 로그에도 남지 않게 `no_log`를 적용했습니다.
- **실패는 빨리, 서버에 닿기 전에**: 필수 환경변수와 키 파일이 없으면 서버에 접속하기 전에 로컬에서 바로 중단합니다.
- **차이는 코드가 아니라 변수로**: role 코드는 서버와 무관하게 두고, 서버별 차이는 `host_vars`에만 둡니다. 우선순위는 role 기본값 → `group_vars` → `host_vars` 순으로 덮어씁니다.

## 문제를 만나고 해결한 기록

| 문제 | 원인 | 해결 |
|---|---|---|
| Ansible 실행 시 `dataclasses` 오류 | pipx가 Python 3.15(프리릴리스)로 설치해 호환되지 않음 | 안정 버전인 Python 3.13으로 재설치 |
| 실행 시 `yaml` 콜백 제거 오류 | 최신 `community.general`에서 해당 콜백이 삭제됨 | `callback_result_format = yaml`로 교체 |
| `apt_repository` 지원 중단 경고 | 곧 제거될 모듈 | `deb822_repository`로 교체하고 예전 방식 파일을 정리하는 task 추가 |
| `--check`에서 Docker/auditd 단계 실패 | 드라이런에서는 패키지가 설치되지 않아 뒤 단계가 대상을 찾지 못함 | 도구의 한계로 판단하고 실제 적용 후 재실행 `changed=0`으로 검증 |
| 사전 검증 play에서 `delegate_to` 오류 | play 수준이 아니라 task/block 수준 속성 | block으로 감싸서 해결 |
| Molecule이 `community.docker`를 못 찾음 | pipx로 설치한 Ansible은 컬렉션을 번들로 포함해 설치를 건너뜀 | `--force`로 사용자 경로에 직접 설치하도록 `make deps` 수정 |
| Molecule에서 `requests` 모듈 오류 | Docker 모듈이 쓰는 Python 환경에 라이브러리 없음 | 해당 환경에 `requests`, `docker` 추가 |

## 프로젝트 구조

```
.
├── ansible.cfg           # Ansible 기본 설정
├── inventory.ini         # 대상 서버 목록
├── site.yml              # 진입점: 사전 검증 후 role 순서대로 적용
├── group_vars/servers.yml  # 전체 서버 공통 변수 (유저 목록, 환경변수 연결)
├── host_vars/            # 서버별 차이 (dev.yml, gpu.yml: 추가로 열 포트, GPU 드라이버 버전)
├── roles/                # common, users, ssh, docker, ufw, auditd, nvidia, motd
├── molecule/default/     # 자동 테스트 시나리오
├── Jenkinsfile           # CI 파이프라인 (lint → syntax → 적용, 비밀값은 Jenkins credentials로 주입)
├── Makefile              # 자주 쓰는 명령 모음
├── requirements.yml      # 필요한 Ansible 컬렉션
├── env.example.sh        # 환경변수 예시
└── .ansible-lint         # 정적 검사 설정
```

## 직접 실행해 보기

**1. 필요한 도구**
- Ansible, `ansible-lint`, 대상 서버(SSH + Python3)
- Molecule 테스트용: Docker

**2. 환경변수 설정**

`env.example.sh`를 `env.sh`로 복사해 값을 채우고 불러옵니다. `env.sh`는 Git에 올라가지 않습니다.

| 변수 | 내용 |
|---|---|
| `ANSIBLE_SSH_KEY_FILE` | 서버 접속용 SSH 개인키 파일 경로 |
| `ALLOWED_SUBNET` | DB 포트 접근을 허용할 서브넷 (CIDR) |
| `ALLOWED_PUBLIC_IP` | DB 포트 접근을 허용할 공인 IP |
| `DEPLOY_PASSWORD_HASH` | `deploy` 유저의 sudo 비밀번호 해시 (`openssl passwd -6`로 생성) |
| `DEPLOY_SSH_PUBKEY` | `deploy` 유저에 등록할 SSH 공개키 |
| `KMJ_SSH_PUBKEY` | `kmj` 유저에 등록할 SSH 공개키 |

```bash
cp env.example.sh env.sh   # 값을 채운 뒤
source env.sh
```

**3. 실행**

```bash
make deps      # 필요한 컬렉션 설치
make lint      # 정적 검사
make syntax    # 문법 검사
make check     # 드라이런 (바뀔 내용만 미리 보기)
make apply     # 실제 적용
make apply     # 한 번 더: changed=0 이면 정상
```

**4. 자동 테스트 (Molecule)**

```bash
pipx install --python python3.13 molecule
pipx inject molecule "molecule-plugins[docker]"
pipx inject ansible requests docker
make deps
make test
```

컨테이너에서는 `common`, `users`, `motd`만 테스트합니다. `ufw`, `ssh`, `docker`, `auditd`는 커널과 systemd에 의존해서 VM에서 검증했습니다.

**5. 감사 로그 확인**

```bash
sudo auditctl -l              # 적재된 감시 규칙
sudo ausearch -k sudoers      # sudo 설정 변경 기록
```

## 범위와 운영 시 참고

- `nvidia` role은 GPU가 있는 서버에서만 드라이버를 설치합니다. 실습용 VM에는 GPU가 없어 "GPU 없음 → 건너뜀" 경로만 확인했고, 실제 드라이버 설치와 `nvidia-smi` 확인은 GPU 서버에서 검증이 필요합니다. 드라이버 설치 후에는 재부팅이 필요하며, 자동 재부팅은 `nvidia_allow_reboot`로 켤 수 있습니다(기본 꺼짐).
- **NAS는 대상에서 제외했습니다.** 사내 NAS는 Synology 제품이라 Ubuntu 서버처럼 `apt`, `ufw`, 표준 계정·sshd 설정 방식으로 관리되지 않습니다. 자체 운영체제(DSM)의 패키지 센터, 방화벽, 계정 관리 기능을 쓰기 때문에, 이 프로젝트의 role(`common`, `users`, `ssh`, `docker`, `ufw`, `auditd`)을 그대로 적용할 수 없어 범위에서 뺐습니다.
- 서버 기반 설정만 다룹니다. nginx 같은 애플리케이션 컨테이너의 배포는 Ansible 밖(compose, CI)에서 관리한다는 전제입니다.
- 실습용 VM에서 검증했습니다. 실서버에 적용할 때는 `--check --diff`로 먼저 확인하고 `--limit`으로 한 대씩 진행합니다.
- 방화벽을 켜기 전에 서비스가 쓰는 포트를 모두 `ufw_extra_rules`에 넣어야 합니다. 빠뜨리면 접속이나 서비스가 끊깁니다.
- Docker가 외부에 공개한 컨테이너 포트는 ufw 규칙을 우회할 수 있으니 운영 시 별도로 확인합니다.
- 유저를 추가하려면 `group_vars/servers.yml`의 `users_list`와 `required_env_vars`, Jenkinsfile의 credentials를 함께 추가합니다.
