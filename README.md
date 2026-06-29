# cocotb-runner
Container to run cocotb tests with verilator.

## What is CoCoTB?
CoCoTB is a coroutine-based cosimulation environment. The idea behind using it is that it's a simpler framework
that requires less work of the user to setup and run tests. cocotb is **NOT** a simulator, rather a tool that uses
other simulators to model the hardawre code and interfaces using a procedural interface. The environment currently
setup uses Verilator to simulate Verilog/Systemverilog. None of the open source simulators supported by cocotb
support cross language simulation (ie both Verilog and VHDL).

## Expected Test Structure

Every test consists of two main parts: test.py, and tb.py.

### tb.py

The `TB` library defined in the helper file is used to create a simple helper library for the model to setup the
neccessary signals and include helper functions for things such as reset.

```python
import logging
import os

import cocotb
# Import whatever specific cocotb modules to use for simulation. Clock must always be included as it models the clock to drive to model.
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


class TB:
    def __init__(self, dut):
        self.dut = dut

        # Start Logging
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # Log TB Parameters
        self.get_params()
        self.display_params()

        # Simulation Signals
        self.get_signals()

        # Start Clock
        cocotb.start_soon(Clock(self.clk, 2, unit="ns").start())

        # Zero out input signals
        self.zero_input_signals()

    def get_params(self):
        self.example_param = int(os.environ.get("PARAM_EXAMPLE_PARAM"))

    def display_params(self):
        self.log.info("module parameters:")
        self.log.info(f"    EXAMPLE_PARAM = {self.example_param}")

    def get_signals(self):
        self.clk = self.dut.clk
        self.rst = self.dut.rst
        self.ex_signal = self.dut.ex_signal

    def zero_input_signals(self):
        self.rst.value = 0

    async def reset(self):
        await RisingEdge(self.clk)
        self.zero_input_signals()
        self.rst.value = 1
        await RisingEdge(self.clk)
        self.rst.value = 0
        await RisingEdge(self.clk)
```

### test.py

```python
import os
import shutil

import cocotb
import pytest
from cocotb_tools.runner import get_runner
from filelock import FileLock
from example import TB


@cocotb.test()
async def test_example(dut):
    tb = TB(dut)
    tb.log.info("Resetting...")
    await tb.reset()

### Create your test here... adding more tests follows the same format. ###
    assert tb.ex_sig == 0


#####################################################################
### ALL OF THE BELOW REMAINS PRETTY MUCH THE SAME FOR EVERY TEST  ###
### YOU JUST NEED TO MODIFY THE PARAMETERS TO PASS PARAMETERS AND ###
### TO HANDLE DIFFERENT COMBINATIONS OF PARAMETERS IF NEEDED.     ###
#####################################################################

tests_dir = os.path.abspath(os.path.dirname(__file__))
base_dir = os.path.abspath(os.path.join(tests_dir, "..", "..", ".."))
### MAKE SURE TO CHANGE THE PATH TO THE RTL AND THE DUT ###
rtl_dir = os.path.abspath(os.path.join(base_dir, "cores", "example"))
dut = "example"

_BUILT_BUILDS = {}
### ALL TESTS GO IN THIS LIST ###
COCOTB_TESTCASES = ["test_example"]
### ADD PARAMETERS TO THIS, ADD MORE IF YOU WANT MORE COMBINATIONS ###
PARAMETER_SETS = [
    {"NUM":0, "EXAMPLE_PARAM":1},
]


@pytest.fixture
def parameters(request):
    return request.param


@pytest.fixture
def cocotb_runner(parameters):
    build_key = "-".join(f"{k}-{v}" for k, v in parameters.items())
    if build_key in _BUILT_BUILDS:
        return _BUILT_BUILDS[build_key]

### ADD YOUR SOURCES HERE ###
    sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    sim = os.getenv("SIM", "verilator")
    build_parameters = {k: v for k, v in parameters.items() if k != "NUM"}
    extra_env = {f"PARAM_{k}": str(v) for k, v in build_parameters.items()}
    build_dir = f"{tests_dir}/sim_build/{dut}_NUM{parameters['NUM']}"

    lock_file = os.path.join(build_dir, ".build.lock")
    os.makedirs(build_dir, exist_ok=True)
    with FileLock(lock_file, timeout=300):
        runner = get_runner(sim)
        runner.build(
            sources=sources,
            hdl_toplevel=dut,
            build_dir=build_dir,
### ADD ARGUMENTS HERE IF YOU NEED TO PASS THINGS TO VERILATOR ###
            build_args=[
                "--coverage",
                "--Wno-WIDTHEXPAND",
                "--Wno-WIDTHTRUNC",
                "--timing",
                "-O3",
            ],
            parameters=build_parameters,
        )

    _BUILT_BUILDS[build_key] = (build_dir, runner, extra_env)
    return build_dir, runner, extra_env


@pytest.mark.parametrize("parameters", PARAMETER_SETS, indirect=True)
@pytest.mark.parametrize("testcase", COCOTB_TESTCASES)
def test_m_fifo_sync_rgw(testcase, cocotb_runner):
    build_dir, runner, extra_env = cocotb_runner
    module = os.path.splitext(os.path.basename(__file__))[0]
    lock_file = os.path.join(build_dir, ".run.lock")

    with FileLock(lock_file, timeout=300):
        runner.test(
            hdl_toplevel=dut,
            test_module=module,
            testcase=testcase,
            extra_env=extra_env,
        )

        cov_src = os.path.join(build_dir, "coverage.dat")
        cov_dst = os.path.join(build_dir, f"coverage_{testcase}.dat")

        if os.path.exists(cov_src):
            shutil.move(cov_src, cov_dst)
```

#### Ruff

There is currently a Ruff linter setup that uses `pyproject.toml` to ensure the python testbenches all maintain the
same standard of code formatting. It uses the default python 3.11 image and installs ruff. The template to do this
elsewhere is as follows:

```yaml
cocotb_python_lint:
  tags:
    - podman-runner
  image: python:3.11
  stage: lint
  rules:
    - changes:
        - <directory to check>/**/*.py
  script:
    - pip install ruff
    - ruff check <directory to check>
    - ruff format --check <directory to check>
```

## Useful Links

- https://www.cocotb.org/
- https://github.com/cocotb/cocotb
- https://docs.cocotb.org/en/stable/quickstart.html
- https://www.veripool.org/verilator/
- https://github.com/verilator/verilator

### UVM
- antmicro.com/blog/2025/10/support-for-upstream-uvm-2017-in-verilator
- https://github.com/nickg/nvc
