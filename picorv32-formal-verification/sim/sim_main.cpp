#include <cstdio>
#include <cstdint>
#include "Vpicorv32.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static uint32_t mem[1024];   // 4 KB memory

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    FILE* f = fopen("prog.hex", "r");
    if (!f) { printf("cannot open prog.hex\n"); return 1; }
    unsigned w; int n = 0;
    while (n < 1024 && fscanf(f, "%x", &w) == 1) mem[n++] = w;
    fclose(f);

    Vpicorv32* top = new Vpicorv32;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("sim.vcd");

    top->clk = 0; top->resetn = 0;
    top->mem_ready = 0; top->mem_rdata = 0;
    top->irq = 0; top->pcpi_wr = 0; top->pcpi_rd = 0;
    top->pcpi_wait = 0; top->pcpi_ready = 0;

    uint64_t t = 0;
    int rc = 2;                       // 2 = timeout, 1 = fail, 0 = pass
    for (int cycle = 0; cycle < 2000 && rc == 2; cycle++) {
        if (cycle == 10) top->resetn = 1;

        top->clk = 0; top->eval(); tfp->dump(t++);
        bool     v = top->mem_valid, r = top->mem_ready;
        uint32_t a = top->mem_addr,  d = top->mem_wdata, s = top->mem_wstrb;

        top->clk = 1; top->eval(); tfp->dump(t++);

        bool ready = false; uint32_t rdata = 0;
        if (v && !r) {
            ready = true;
            if (s) {
                if (a == 0x10000000u) {
                    printf("HALT write: data=0x%08x\n", d);
                    rc = (d == 12) ? 0 : 1;
                } else if (a < 4096) {
                    uint32_t idx = a >> 2;
                    for (int i = 0; i < 4; i++)
                        if (s & (1u << i))
                            mem[idx] = (mem[idx] & ~(0xFFu << (8*i))) | (d & (0xFFu << (8*i)));
                    printf("WRITE addr=0x%08x data=0x%08x strb=0x%x\n", a, d, s);
                }
            } else {
                rdata = (a < 4096) ? mem[a >> 2] : 0;
            }
        }
        top->mem_ready = ready; top->mem_rdata = rdata; top->eval();

        if (top->trap) { printf("TRAP asserted at cycle %d\n", cycle); rc = 1; }
    }

    printf(rc == 0 ? "PASS\n" : (rc == 1 ? "FAIL\n" : "TIMEOUT\n"));
    top->final(); tfp->close(); delete top; delete tfp;
    return rc;
}
