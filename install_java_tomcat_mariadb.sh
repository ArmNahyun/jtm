#!/bin/bash

# 스크립트 실행 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "이 스크립트는 루트 권한으로 실행되어야 합니다. sudo를 사용하여 다시 시도해주세요."
    exit 1
fi

echo "--- 시스템 업데이트 시작 ---"
apt update && apt upgrade -y
echo "--- 시스템 업데이트 완료 ---"

echo "--- OpenJDK 17 설치 시작 ---"
apt install -y openjdk-17-jdk
echo "JAVA_HOME 환경 변수 설정..."
echo 'JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"' | tee -a /etc/environment
echo 'PATH="$PATH:$JAVA_HOME/bin"' | tee -a /etc/environment
source /etc/environment
echo "Java 버전 확인:"
java -version
echo "--- OpenJDK 17 설치 완료 ---"

---

echo "--- MariaDB Server 설치 시작 ---"
apt install -y mariadb-server mariadb-client
echo "MariaDB 서비스 시작 및 활성화..."
systemctl start mariadb
systemctl enable mariadb
echo "MariaDB 보안 설정 시작 (root 비밀번호 설정, 익명 사용자 제거 등)"
echo "이 단계에서 MariaDB 보안 설정을 수동으로 진행해야 합니다."
echo "엔터 키를 누른 후 'mysql_secure_installation' 프롬프트에 따라 진행해주세요."
read -p "진행하시려면 엔터 키를 누르세요..."
# MariaDB도 MySQL과 동일한 mysql_secure_installation 스크립트를 사용합니다.
mysql_secure_installation
echo "--- MariaDB Server 설치 완료 ---"

---

echo "--- Apache Tomcat 10 설치 시작 ---"
# Tomcat 다운로드 URL (최신 버전 확인 필요 - 이 예시는 10.1.x 버전)
TOMCAT_VERSION="10.1.42" # 최신 안정 버전으로 업데이트해주세요.
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_DIR="/opt/tomcat"

echo "Tomcat 다운로드 중... (${TOMCAT_URL})"
wget -q ${TOMCAT_URL} -O /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz

echo "Tomcat 압축 해제 및 이동..."
mkdir -p ${TOMCAT_DIR}
tar -xzf /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/
mv /opt/apache-tomcat-${TOMCAT_VERSION} ${TOMCAT_DIR}

echo "Tomcat 사용자 생성..."
groupadd tomcat
useradd -s /bin/false -g tomcat -d ${TOMCAT_DIR} tomcat

echo "Tomcat 디렉토리 권한 설정..."
chown -R tomcat:tomcat ${TOMCAT_DIR}
chmod -R u+rwx,g+rx,o+rx ${TOMCAT_DIR}
chmod -R g+w ${TOMCAT_DIR}/work ${TOMCAT_DIR}/temp ${TOMCAT_DIR}/logs

echo "Tomcat Systemd 서비스 파일 생성..."
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_HOME=${TOMCAT_DIR}"
Environment="CATALINA_BASE=${TOMCAT_DIR}"
ExecStart=${TOMCAT_DIR}/bin/startup.sh
ExecStop=${TOMCAT_DIR}/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Tomcat 서비스 데몬 재로드 및 시작..."
systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat

echo "Tomcat 상태 확인:"
systemctl status tomcat --no-pager

echo "--- Apache Tomcat 10 설치 완료 ---"

echo "--- 모든 설치 및 설정 완료 ---"
echo "설치된 버전:"
java -version
mysql --version # MariaDB도 'mysql --version'으로 버전 확인 가능
echo "Tomcat은 http://localhost:8080 에서 접근 가능합니다."
