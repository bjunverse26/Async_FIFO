# Constraints

Async FIFO는 서로 비동기인 write/read clock domain을 연결하므로, implementation constraints는 대상 FPGA와 clock 구성에 맞춰 작성해야 합니다.

실제 implementation에서는 다음 항목을 함께 검토해야 합니다.

- `i_wclk`, `i_rclk`의 개별 clock period
- 두 clock domain의 asynchronous relationship
- Gray-code pointer synchronizer의 placement 및 CDC constraints
- 독립 reset의 assertion/deassertion policy

이 저장소는 RTL 동작과 self-checking simulation을 제공합니다. Target-specific XDC는 대상 FPGA가 확정된 뒤 synthesis·implementation·CDC report와 함께 관리합니다.
