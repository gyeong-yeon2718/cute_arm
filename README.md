<div align="center">

# 개인 3DOF 로봇팔

**Arduino · 서보 구동 · 캘리브레이션 · 실제 보드 검증**

[제작·검증 기록](docs/calibration-log.md) · [문제 분석](docs/findings.md) · [개인 포트폴리오](https://github.com/gyeong-yeon2718)

</div>

---

## 프로젝트 한눈에 보기

| 구분 | 내용 |
| --- | --- |
| 프로젝트 | 개인 로봇팔 제작·캘리브레이션 |
| 개인 작업 | 기구·회로 구성, 하드웨어 적용, 캘리브레이션과 검증 기록·도구 |
| 구동 구성 | 3자유도 로봇팔, 그리퍼를 포함한 SG90 서보모터 4개 |
| 확인할 자료 | [보정 과정](docs/calibration-log.md), [펌웨어 분석](docs/firmware-analysis.md), [발견 사항](docs/findings.md) |
| 외부 코드 | elevenMiles의 Seven 펌웨어 활용 · MIT · [원저자 고지](NOTICE.md) |

보드의 입력 명령과 실제 하드웨어 상태를 구분하며 제작 과정을 기록한 프로젝트입니다.
시리얼 연결 시 리셋, EEPROM 확인, 이론 좌표와 위치 피드백의 차이를 검증 문서에서 다룹니다.

---

3자유도(3-DOF) 아두이노 로봇 암 제작, 캘리브레이션 및 검증 기록.

펌웨어는 elevenMiles의 **Seven** 프로젝트([Upstream](https://github.com/elevenMiles/Robotic_Arm_Seven), MIT)를 기반으로 합니다.
이 리포지토리는 *개인 빌드* 기록으로, 실제 보드에서 동작하는 코드, 캘리브레이션 과정, 측정 데이터 및 직접 작성한 도구들을 포함합니다. 작성자 작업물과 외부 라이선스 구분은 [NOTICE.md](NOTICE.md)를 참고하세요.

## 하드웨어

| 항목 | 내용 |
|---|---|
| 컨트롤러 | Arduino Uno (정품, `VID_2341` / `PID_0043`) |
| 시리얼 | **115200** baud, 현재 PC 연결: `COM7` |
| MCU | ATmega328P, 32 KB flash (Optiboot 부트로더), 2 KB RAM, 1 KB EEPROM |
| 서보 모터 | 4× SG90 — 베이스 `D6`, 어깨 `D9`, 팔꿈치 `D10`, 그리퍼 `D11` |
| 링크 길이 | 어깨→팔꿈치 **12.0 cm**, 팔꿈치→그리퍼 **12.0 cm** |
| 도달 범위 | 어깨 피벗 기준 3 cm (최소) ~ 23 cm (최대) |

플래시 메모리 사용량: **16,610 / 32,256 bytes (51%)**, RAM **820 / 2048 bytes (40%)**.  
측정된 제어 루프 속도: **~2,410 Hz**.

## 현재 캘리브레이션 설정

EEPROM 주소 0번지에 5개의 리틀 엔디안 float 형태로 저장되며, 전원이 꺼져도 유지됩니다.

| 항목 | 설정값 |
|---|---|
| `calib_base` | **5.0°** |
| `calib_shoulder` | 0.0° |
| `calib_elbow` | **5.0°** |
| `gripper_open` | **45.0°** |
| `gripper_close` | 0.0° |

2026-07-30 캘리브레이션 완료 — 상세 절차 및 검증 기록은 [docs/calibration-log.md](docs/calibration-log.md) 참고.

## 좌표계

원점 `(0,0,0)`은 **어깨 서보의 피벗** 위치입니다. 단위는 센티미터(cm)입니다.

| 축 | 방향 |
|---|---|
| X | 앞 / 뒤 |
| Y | 좌 / 우 |
| Z | 위 / 아래 |

캘리브레이션된 기본 대기 자세(Rest pose)는 `(12, 0, 12)`입니다. (위쪽 팔은 수직, 전완은 수평으로 숫자 "7" 모양을 이웁니다.)

## 빠른 시작

115200 baud 속도로 시리얼 모니터를 열고 명령어를 입력합니다. 부팅 시 출력 메시지:

```
Robotic arm initialized.
If this is the first run, please use -R command to reset all calibration angles.
```

주요 명령어:

```
A(15 0 5)    그리퍼를 x=15cm, y=0, z=+5cm 위치로 이동 (역운동학 IK)
M(90 90 90)  각 관절 각도를 직접 설정 (베이스, 어깨, 팔꿈치)
U(3) D(3)    상/하 3 cm 이동 (L R F B 사용 가능; 단독 문자는 5 cm 이동)
O            기본 대기 자세로 복귀
GO / GC      그리퍼 열기 / 닫기
G(30)        그리퍼 특정 각도 설정
S(60)        관절 이동 속도 설정 (30..90 deg/sec 범위 제한)
T            현재 엔드 이펙터 위치 출력
```

전체 명령어 목록은 [`firmware/main/main.ino`](firmware/main/main.ino) 주석에 작성되어 있습니다. (`T` 명령어 누락 관련 사항은 [docs/findings.md](docs/findings.md) 참고)

## 리포지토리 구조

```
firmware/          Seven 펌웨어 (업스트림 코드로 변경 없음, MIT 라이선스, elevenMiles)
  main/            실제 보드에 업로드되어 실행되는 메인 코드
  test/            서보별 조립 테스트용 스케치
tools/             작성한 캘리브레이션 및 관리 도구
  calibrate.ps1    방향키 기반 캘리브레이션 조거 스크립트
  read-eeprom/     EEPROM 캘리브레이션 구조체를 덤프하는 임시 스케치
docs/
  firmware-analysis.md   펌웨어 내부 동작 방식 분석 문서
  calibration-log.md     캘리브레이션 진행 세션, 값 및 검증 데이터
  findings.md            펌웨어 버그 및 문서 불일치 분석
```

## 보드 작업 시 주의사항

1. **시리얼 포트를 열면 Uno가 리셋됩니다.** 리셋 시 로봇 암은 `90 + calib` 위치로 튀며, 그리퍼는 `gripper_open` 위치로 이동합니다. 기존에 조정해 둔 자세 정보는 초기화됩니다.
2. **Optiboot는 EEPROM 직접 읽기/쓰기를 지원하지 않습니다.** `avrdude -U eeprom:r` 명령은 성공하는 것처럼 보이지만 실제로는 *Flash* 바이너리를 출력합니다. 실제 EEPROM을 읽으려면 전용 임시 스케치가 필요합니다. ([tools/README.md](tools/README.md) 참고)
3. **서보 모터에 위치 피드백(Position Feedback)이 없습니다.** `T` 명령어가 출력하는 좌표는 입력받은 각도로부터 계산된 *이론상* 위치입니다. 서보가 탈조되거나 장애물에 걸려도 보드는 정위치에 있다고 인식합니다.

## 로드맵 (Roadmap)

- [ ] 웨이포인트 재경로 반복 실행(Looping) 버그 수정 ([docs/findings.md](docs/findings.md) 참고)
- [ ] 펌웨어 헤더 주석에 `T` 명령어 명세 추가
- [ ] `gripper_close = 0°` 설정 시 기계적 스토퍼에 서보가 걸려 과열되는지 확인
- [ ] 향후 계획: 해당 하드웨어에 맞춘 자체 펌웨어를 처음부터 새로 작성하고 기존 `firmware/` 대체

## 라이선스

- 본 리포지토리의 작업물 (`docs/`, `tools/`, 본 README): MIT License ([LICENSE](LICENSE) 참고)
- `firmware/` 하위 펌웨어: MIT License, © 2026 elevenMiles ([`firmware/LICENSE`](firmware/LICENSE) 및 [NOTICE.md](NOTICE.md) 참고)
