# 전역 변수 선언
ARG DB_URL="jdbc:h2:tcp://host.docker.internal/~/test"
ARG DB_DRIVER_CLASS_NAME="org.h2.Driver"
ARG DB_USERNAME="sa"
ARG DB_PWD=

# 첫번째 스테이지
# openjdk 베이스로 소스파일 빌드
# AS = alias
FROM openjdk:11 AS build
# 작업 디렉토리를 /app으로 설정
WORKDIR /app

# 임시 컨테이너로 build.gradle, settings.gradle 전송
# 디펜던시 목록에 변화가 없을 경우 캐싱된 레이러를 활용하기 위함
COPY ./gradle ./gradle
COPY gradlew build.gradle settings.gradle ./
RUN ./gradlew dependencies

# DB_URL = 연결되어야 하는 DB주소
# DB_DRIVER_CLASS_NAME = DB 드라이버 클래스 이름
# DB_USERNAME = DB ID
# DB_PWD = DB PASSWD, 별도 설정되어 있지 않다면 생략
# 현재 로컬 호스트의 H2 DB에 연결됨
ARG DB_URL \
    DB_DRIVER_CLASS_NAME \
    DB_USERNAME \
    DB_PWD
ENV ENV_DB_URL=${DB_URL} \
    ENV_DB_DRIVER_CLASS_NAME=${DB_DRIVER_CLASS_NAME} \
    ENV_DB_USERNAME=${DB_USERNAME} \
    ENV_DB_PWD=

# src 폴더를 컨테이너의 ./src 폴더로 복사
COPY src ./src

# 소스코드 빌드
RUN ./gradlew build

# 두번째 스테이지
# JVM만 가동하려는 목적으로 jre 베이스 이미지 가져오기
FROM openjdk:11-jre-slim AS deploy

WORKDIR /app

ARG DB_URL \
    DB_DRIVER_CLASS_NAME \
    DB_USERNAME \
    DB_PWD

ENV ENV_DB_URL=${DB_URL} \
    ENV_DB_DRIVER_CLASS_NAME=${DB_DRIVER_CLASS_NAME} \
    ENV_DB_USERNAME=${DB_USERNAME} \
    ENV_DB_PWD=

# --from=alias
# 첫번째 스테이지에서 빌드된 .jar파일만 가져와서 /app/app.jar 파일로 복사
# -plain.jar 파일은 제외
COPY --from=build /app/build/libs/*-SNAPSHOT.jar app.jar

# app.jar 파일 실행
CMD ["java", "-jar", "app.jar"]