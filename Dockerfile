
FROM docker.io/library/debian:stable-slim

# Install needed libraries for verilator build and cocotb runtime
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-wheel python3-venv \
    autoconf g++ bison flex git make git help2man perl \
    libfl2 libfl-dev zlib1g zlib1g-dev \
    ccache mold libgoogle-perftools-dev numactl \
    curl gpg \
    && rm -rf /var/lib/apt/lists/*

# Pull verilator source and build
WORKDIR /usr/src/
ENV VERILATOR_VERSION=5.048
RUN git clone --depth 1 --branch v${VERILATOR_VERSION} https://github.com/verilator/verilator.git
WORKDIR /usr/src/verilator
RUN autoconf && ./configure && make -j `nproc` && make install
WORKDIR /usr/src/
RUN rm -rf verilator

# Setup python virtual environment for cocotb
ENV VIRTUAL_ENV=/usr/src/.venv
RUN python3 -m venv ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Install needed python libraries
COPY requirements.txt .
RUN pip3 install -r requirements.txt && \
    rm requirements.txt

# Jank way to have the virtual environment activated
ENTRYPOINT ["/bin/bash", "-c", ". /usr/src/.venv/bin/activate && exec /bin/bash"]
