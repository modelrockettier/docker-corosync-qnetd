# Cross compiling for ARM

If you try to build this on x86, it will fail since ARM binaries can't run
natively on x86 CPUs. In order to work around this, you will need to install
qemu, which will translate the ARM machine code into x86 instructions.

## Use docker buildx

1. Build using docker buildx
   ```
   docker buildx build --platform linux/arm64/v8 --tag corosync-qnetd:arm64v8 .
   ```

## The manual instructions

1. Install qemu-user-static and binfmt-support
   ```
   apt-get install binfmt-support qemu qemu-user-static
   ```

2. Register QEMU with the system so it knows how to handle ARM binaries
   ```
   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
   ```

3. Build the code as normal
   ```
   make
   # Or
   docker build -t corosync-qnetd:v3-arm64v8 .
   ```
