# Asynchronous FIFO & Handshake CDC

서로 다른 write/read clock domain 사이에서 연속 데이터를 전달하는 dual-clock FIFO와, 단일 word를 request/acknowledge 방식으로 전달하는 handshake CDC를 SystemVerilog로 구현한 프로젝트입니다.

## 설계 핵심

- Address 계산은 각 domain의 binary pointer로 수행합니다.
- Clock domain을 넘는 pointer는 Gray code로 변환해 two-flop synchronizer로 전달합니다.
- Pointer와 request/acknowledge synchronizer register에 `ASYNC_REG` 속성을 적용했습니다.
- Write domain은 동기화된 read pointer로 `full`을, read domain은 동기화된 write pointer로 `empty`를 판정합니다.
- Memory write는 `i_wclk`에 동기화되고 read data는 현재 read address에서 조합적으로 출력됩니다.
- 서로 다른 clock을 사용하는 self-checking testbench와 queue scoreboard를 구성했습니다.
- 단발성 데이터 전달을 비교할 수 있도록 별도의 `HandshakeCdc` 예제를 포함합니다.

## Async FIFO Architecture

```text
Write domain (i_wclk)                         Read domain (i_rclk)

i_wdata ──> FifoMem[write address] ───────────────> o_rdata
              ▲                                      ▲
           WptrFull                               RptrEmpty
      binary ──> Gray pointer                binary ──> Gray pointer
              │                                      │
              └── 2-FF sync ──> read domain          └── 2-FF sync ──> write domain

        synchronized read Gray                    synchronized write Gray
               │                                         │
               └── full compare                 empty compare ──┘
```

Remote pointer는 synchronization latency 이후 보이므로 `full`과 `empty`의 해제는 보수적으로 늦어질 수 있습니다. 이는 아직 안전하게 관측되지 않은 공간이나 데이터를 사용하지 않도록 하는 구조입니다.

## 기본 사양

| 항목 | 기본값 |
| --- | --- |
| Data width | 8-bit |
| Address width | 4-bit |
| FIFO depth | 16 entries (`2^FIFO_ADDR`) |
| Write interface | `i_winc`, `i_wdata`, `o_wfull` |
| Read interface | `i_rinc`, `o_rdata`, `o_rempty` |
| Resets | Domain별 active-low asynchronous reset |
| FIFO testbench top | `TbAsyncFifo` |
| Handshake testbench top | `TbHandshakeCdc` |
| Handshake source control | `o_ready_src`가 1일 때 `i_valid_src` 수락 |

현재 full comparator는 pointer의 상위 두 bit를 비교하므로 parameter는 `FIFO_ADDR >= 2`, depth는 `2^FIFO_ADDR`인 구성을 전제로 합니다.

## Pointer와 Flag 동작

| Domain | Local state | Crossing signal | Flag condition |
| --- | --- | --- | --- |
| Write | Binary write pointer와 write address | Gray write pointer를 read domain으로 전달 | Next write Gray pointer가 동기화된 read Gray pointer의 상위 2bit 반전값과 일치하면 full |
| Read | Binary read pointer와 read address | Gray read pointer를 write domain으로 전달 | Next read Gray pointer가 동기화된 write Gray pointer와 일치하면 empty |

Write는 `i_winc && !o_wfull`, read pointer 이동은 `i_rinc && !o_rempty`일 때만 발생합니다.

## Handshake CDC

`HandshakeCdc`는 source가 데이터를 hold하고 request를 올린 뒤, destination에서 request를 동기화·capture하고 acknowledge를 되돌리는 구조입니다. Source는 `o_ready_src`가 1일 때만 새 데이터를 전달합니다.

```text
Source: capture data → request=1 ───────────────┐
                                                ▼
Destination:                 sync request → capture → valid pulse → ack=1
                                                │
Source:                       sync ack <────────┘ → request=0
Destination: request=0 확인 → ack=0
```

`o_ready_src`는 request가 내려가고 acknowledge가 source domain에서 해제된 뒤 다시 1이 됩니다. Testbench도 이 신호를 기다린 뒤 다음 word를 전달하므로 clock ratio와 무관하게 이전 handshake의 완료를 보장합니다.

## Verification

| Testbench | 시나리오 | 확인 내용 |
| --- | --- | --- |
| `TbAsyncFifo` | 16개 write 후 fill | `o_wfull` assertion |
| `TbAsyncFifo` | FIFO 전체 drain | `o_rempty` assertion |
| `TbAsyncFifo` | Interleaved write/read | Queue scoreboard 기반 순서·데이터 무결성 |
| `TbAsyncFifo` | Write 10 ns, read 22 ns period | 서로 다른 clock에서 pointer synchronization 동작 |
| `TbHandshakeCdc` | `A5`, `3C`, `F0` 순차 전달 | Destination valid 횟수와 수신값 자동 비교 |

두 testbench 모두 오류를 집계하고 실패가 없으면 종료 코드 0을 반환합니다. 현재 검증은 고정 clock ratio와 directed scenario를 사용한 RTL simulation입니다. Randomized clock/phase, 동작 중 domain별 독립 reset, static CDC, formal verification, synthesis 결과는 현재 증거 범위에 포함되지 않습니다.

## Simulation

Queue와 SystemVerilog interface를 지원하는 simulator가 필요합니다.

### Icarus Verilog 12.0

```bash
mkdir -p sim

iverilog -g2012 -s TbAsyncFifo -o sim/async_fifo \
  rtl/FifoMem.sv rtl/WptrFull.sv rtl/RptrEmpty.sv rtl/AsyncFifo.sv \
  tb/TbAsyncFifo.sv
vvp sim/async_fifo

iverilog -g2012 -s TbHandshakeCdc -o sim/handshake_cdc \
  rtl/HandshakeCdc.sv tb/TbHandshakeCdc.sv
vvp sim/handshake_cdc
```

두 testbench는 Icarus Verilog 12.0과 Verilator 5.020에서 교차 실행했으며, FIFO fill/drain/interleaved 시나리오와 ready 기반 3-word handshake가 모두 통과했습니다.

### Async FIFO

1. `rtl/FifoMem.sv`, `rtl/WptrFull.sv`, `rtl/RptrEmpty.sv`, `rtl/AsyncFifo.sv`를 design source로 추가합니다.
2. `tb/TbAsyncFifo.sv`를 추가하고 simulation top을 `TbAsyncFifo`로 지정합니다.

### Handshake CDC

1. `rtl/HandshakeCdc.sv`와 `tb/TbHandshakeCdc.sv`를 추가합니다.
2. Simulation top을 `TbHandshakeCdc`로 지정합니다.

도구별 실행 script는 포함되어 있지 않으므로 compile/elaboration option은 사용하는 simulator에 맞게 지정해야 합니다.

## Repository Guide

| 경로 | 내용 |
| --- | --- |
| `rtl/AsyncFifo.sv` | Dual-clock FIFO integration과 pointer synchronizers |
| `rtl/WptrFull.sv` | Write pointer와 full generation |
| `rtl/RptrEmpty.sv` | Read pointer와 empty generation |
| `rtl/FifoMem.sv` | Synchronous write, asynchronous read storage |
| `rtl/HandshakeCdc.sv` | Single-word request/acknowledge CDC |
| `tb/TbAsyncFifo.sv` | FIFO scoreboard testbench |
| `tb/TbHandshakeCdc.sv` | Handshake CDC self-checking testbench |

## License

This project is distributed under the [MIT License](LICENSE).
