use io;
use i2c;
use spi;
try { i2c.open("/dev/i2c-1", 0x44); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { spi.open("/dev/spidev0.0"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { i2c.open("/etc/hostname", 0x44); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { spi.open("/etc/hostname"); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
try { i2c.open("/dev/i2c-1", 0x80); } catch (e) { io.printf("%s: %s\n", $e.kind, $e.message); }
