# goorm-assign1
구름톤 트레이닝(쿠버네티스15회차)과제 1번

## 과제 설명
강의 "스프링 입문 - 코드로 배우는 스프링 부트, 웹 MVC, DB 접근 기술" 에서 우리는 간단한 회원 관리 애플리케이션을 구현해보았습니다.   
본 과제는 우리가 구현한 웹 서버를 컨테이너 이미지로 만들어보는 과제 입니다.   

## 결과물
- 이미지 빌드를 위한 Dockerfile, docker-compose 파일이 올라간 결과물 레포 주소
- 빌드된 도커 이미지 주소

## 하위과제
- 도커 이미지 빌드하기(docker hub)
- 도커 이미지 실행해서 동작 확인하기
- docker-compose를 사용하여 도커 이미지 실행하기

## 참고사항
위 파일중 docker-compose.yml 파일을 통해 H2 Database와 서버 애플리케이션 컨테이너를 동작 시킬수 있습니다.   
단, 다른 DB에 대한 연결시 환경변수 설정이 필요합니다.
 - ENV_DB_URL : DB URL
 - ENV_DB_DRIVER_CLASSN_NAME : DB Dirver class
 - ENV_USERNAME : DB user name
 - ENV_PWD : DB user passwd

<p>$\it{\large{\color{#DD6565}주의! 해당\  서버\  애플리케이션은\  JPA \ DDL-AUTO : Create 모드입니다.}}$</p>

---


# 궁금한 것
## 1. Travis CI를 현업에서도 많이 사용 하는가?
Travis CI를 private 하게 운영하려면 비용이 발생한다.   
또한, 소스 코드가 private 이라고 한들 외부로 나가는건데 과연 현업에서도 많이들 사용하는지 궁금 하다.   
오픈 소스가 아닌 이상에서야 해당 서비스의 소스코드를 차라리 EC2위에서 젠킨스와 같은 CI 도구를 이용해서 빌드, 배포 환경을 구성하거나 회사 내부의 빌드, 배포 환경을 구축하는것이 더 보안 측면에서 좋아 보인다.   

## 2. 서버 이미지 배포시 DB 관련된 테스트는 어떻게 구성 하는가?
docker 컨테이너를 통한 서버 파일 배포시 테스트시 DB를 어디에 어떻게 띄울지에 대해 많이 고민 되었는데   
현업에서는 이런 문제는 어떻게 해결하고 있는지??   
여러 고민을 해보았지만, 완전히 DB에 종속되지 않으면서도 확장 가능한(여러 DB에 대한 접근을 상황에 맞게 최소한의 변경만으로 가능하게) 이미지를 배포하지 못했다   

---

# 삽질 일기
## 1. 컨테이너 (서버) <-> 로컬 호스트 (H2 DB) 통신 문제
도커 파일의 첫번째 스테이지에서 통합 테스트 케이스에서 FAILED이 뜨면서 서버 파일 빌드가 되지 않았다. 
"org.hibernate.HibernateException at DialectFactoryImpl.java" 라는 키워드로 검색 해보니, H2와 관련된 문제로 확인된다.   
스프링 컨테이너가 데이터베이스 커넥션에 대한 빈을 생성 해야 되는데 연결이 불가능 하니 빈을 생성하지 못해서 발생 하는 에러로 보였다.   

해결 방법은 생각보다 간단했다.   
이미지 생성시 사용되는 임시 컨테이너에서 로컬 호스트의 DB H2로 접속을 해야 한다.   
먼저 부트 프로젝트의 application.properties 파일을 아래와 같이 수정 해야 한다.   
```
# application.properties
# 기존 내용
spring.datasource.url=jdbc:h2:tcp://localhost/~/test
spring.datasource.driver-class-name=org.h2.Driver
spring.datasource.username=sa
...

# 수정 내용
# 환경 변수에 DB 정보를 셋팅 한다.
# 또한, 로컬 개발 환경에서 테스트용 DB 정보를 콜론 뒤에 써주면 환경 변수가 없을땐 해당 URL로 동작한다
spring.datasource.url=${DB_URL:jdbc:h2:tcp://localhost/~/test}
spring.datasource.driver-class-name=${DB_DRIVER_CLASS_NAME:org.h2.Driver}
spring.datasource.username=${USERNAME:username}
...
```
그리고 dockerfile에서 임시 컨테이너 환경 변수를 설정 해주면 된다.
이때, localhost 부분을 변경 해야 함
왜냐하면 임시 컨테이너상에서 localhost는 자기 자신을 가르키기 때문에 호스트 OS 혹은 DB서버의 IP주소 입력
참고로 컨테이너에서 호스트 IP주소를 알고 싶을때 "host.docker.internal"을 입력하면 호스트 IP 주소로 대치됨
```
# dockfile

...
ENV DB_URL="DB 주소" \
    DB_DRIVER_CLASS_NAME="Driver Class Name"
    USERNAME="UserName"
...
```

이렇게 작업을 해두면, 이후 다른 DB에 붙여야 할때도 dockerfile 내부에 환경변수 셋팅만 변경 해주면 되겠다.

```
# multi-stage 에서 사용하기 위해 ARG 명령어를 사용해서 각 설정값 전역변수화 하기
ARG DB_URL="jdbc:h2:tcp://host.docker.internal/~/test" \
    DB_DRIVER_CLASS_NAME="org.h2.Driver" \
    DB_USERNAME="sa" \
    DB_PWD=

```
위 처럼 ARG 키워드를 사용하면 외부에서도 값 주입이 가능하고, 변수처럼 사용이 가능하다.
단! FROM 이전에 선언한 전역적 ARG 반드시 내부에 ARG key 형태로 다시 한번 선언해주어야 스테이지 내부에서 사용 가능
```
# FROM 이전에 전역으로 선언한 ARG를 해당 스테이지에서 사용하기 위해 다시 선언만 해준다
FROM openjdk:11 as build

ARG DB_URL \
    DB_DRIVER_CLASS_NAME \
    DB_USERNAME \
    DB_PWD

ENV ENV_DB_URL=${DB_URL} \
    ENV_DB_DRIVER_CLASS_NAME=${DB_DRIVER_CLASS_NAME} \
    ENV_DB_USERNAME=${DB_USERNAME} \
    ENV_DB_PWD=
```

## 2. 컨테이너 <-> 컨테이너 통신 하기
H2를 호스트에서 말고 따로 컨테이너를 띄워 docker-compose를 사용하여 한번에 띄우고 싶어졌다.   
일단 H2 docker 이미지를 통해 컨테이너를 하나 띄워 보았다.
```
# 1521은 H2 데이터베이스 연곃하기 위한 PORT
# 81은 H2 콘솔에 접속하기 위한 PORT
# H2 컨테이너 생성시 필수 옵션이 있음
# H2_OPTIONS 환경변수의 값이 ifNotExists 여야만 테이블 생성이 가능하다.
# H2 docker image 이름은 oscarfonts/h2
docker run -p 1521:1521 -p 81:81 --name h2 oscarfonts/h2
```
콘솔은 정상적으로 들어가지고 테이블 생성까지 문제가 없다.    
이제 서버 컨테이너와 H2 컨테이너가 연결이 되어야 하는데 알아보니 docker network 라는게 있더라   
https://docs.docker.com/network/   
한 네트워크 안에 컨테이너가 같이 있을때는 서로 통신이 가능하다는 결론을 도출했다.   
```
# 현재 형성되어 있는 도커 네트워크 확인
docekr network list
# 네트워크 안에 호스트(컨테이너)들 확인
docker network inspect "network ID, Name"
```
아래 보이는것과 같이 2개의  bridge 네트워크가 있었고
![image](https://github.com/ks00141/goorm-assign1/assets/60214982/2dcdff5d-70b4-4a32-81fb-c0735696275e)   
각 네트워크 안에 서버 컨테이너와 H2 컨테이너가 있었다.   
(docker-compose 이용해서 생성하면 compose network가 생성 되는듯 보인다.)   
![image](https://github.com/ks00141/goorm-assign1/assets/60214982/b291409c-07f3-4654-b723-c89120538302)

![image](https://github.com/ks00141/goorm-assign1/assets/60214982/63711017-f3b0-4a40-84db-4eecf978be30)   

H2 컨테이너를 compose-test_default 네트워크 안으로 옮겨서 실행 시킨다면? 두 컨테이너끼리 통신이 가능해 보였고   
```
# --network "network ID, Name" 옵션을 통해 네트워크 지정이 가능하다.
# h2 컨테이너를 서버 컨테이너의 네트워크에서 생성
docker run -p 1521:1521 -p 81:81 --name h2 --network test-compose_default oscarfonts/h2
```
보이는 것과 같이 하나의 네트워크에 두 컨테이너가 같이 생성 되었다.    
![image](https://github.com/ks00141/goorm-assign1/assets/60214982/67fe16c1-e418-428c-920d-c07844d5833f)
서버 컨테이너를 실행 할 때 ENV_DB_URL 환경변수를 해당 컨테이너의 주소로 넘겨 주면 정상적으로 연결이 되고 실행이 된다.
(H2 테이블은 생성 해줘야함, localhost:81)   

근데 docker-compose 사용하면 애초에 같은 네트워크상에서 컨테이너 만들어 주기 때문에 컴포즈를 사용하자!
```
# DB가 먼저 뜨고 서버가 떠야 하기 때문에
# depens 옵션을 설정해주자
depends_on:
      - db # DB 컨테이너 이름
```
