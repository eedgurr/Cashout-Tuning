# Microcontroller Debugging Techniques

This guide collects techniques for debugging the microcontrollers used alongside Cashout Performance Tuning.

## Serial Logging
- Configure a UART or serial interface to emit debug messages.
- Use a USB-to-Serial adapter or the MCU's built-in interface to monitor output.
- Wrap debug prints so they can be compiled out for production builds.

## Hardware Breakpoints & Stepping
- Connect a hardware debugger via JTAG or SWD (e.g., ST-Link, J-Link).
- Use tools such as GDB or OpenOCD to set breakpoints, inspect memory, and step through code.

## LED Indicators
- Toggle on-board LEDs to signal code paths or error states.
- Useful when serial output isn't available.

## Assertions and Error Handlers
- Add assert macros to validate assumptions during development.
- Implement a centralized error handler to capture faults and reset logic.

## Timing & Performance Measurement
- Utilize cycle counters or hardware timers to measure execution time.
- Employ logic analyzers or oscilloscopes to verify signal timing and external interactions.

These techniques provide visibility into firmware behavior and help diagnose issues on embedded targets.
