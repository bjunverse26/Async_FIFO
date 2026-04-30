# Async FIFO

## 프로젝트 개요

Async FIFO는 서로 다른 write clock과 read clock 사이에서 데이터를 안전하게 전달하기 위한 dual-clock FIFO RTL 프로젝트입니다. write/read pointer는 각 clock domain에서 binary로 관리하고, clock domain을 넘길 때는 Gray code pointer를 two-flop synchronizer로 전달합니다.

## 주요 특징

- dual-clock FIFO 구조 지원
- Gray-coded pointer 기반 full/empty 판정
- write/read pointer용 two-flop synchronizer 적용
- single-word request/acknowledge 방식의 `HandshakeCdc` 예제 포함
- interface, task, scoreboard 기반 self-checking 테스트벤치 제공

## 상세 스펙

| 항목 | 내용 |
| --- | --- |
| 기본 데이터 폭 | 8-bit |
| 기본 FIFO 주소 폭 | 4-bit |
| 기본 FIFO 깊이 | 16 entries |
| Write domain | `i_wclk`, `i_wrst_n`, `i_winc`, `i_wdata`, `o_wfull` |
| Read domain | `i_rclk`, `i_rrst_n`, `i_rinc`, `o_rdata`, `o_rempty` |
| 핵심 RTL | `rtl/AsyncFifo.sv`, `rtl/WptrFull.sv`, `rtl/RptrEmpty.sv`, `rtl/FifoMem.sv` |
| CDC 예제 | `rtl/HandshakeCdc.sv` |
| 테스트벤치 | `tb/TbAsyncFifo.sv`, `tb/TbHandshakeCdc.sv` |

## 검증 결과 요약

- FIFO fill/drain 시나리오에서 full/empty flag 동작 자동 확인
- 서로 다른 write/read clock에서 queue scoreboard로 데이터 순서 보존 검증
- interleaved write/read 시나리오로 pointer synchronization 중 데이터 무결성 확인
- `HandshakeCdc` 테스트벤치에서 request/acknowledge 기반 single-word 전달값 자동 비교
