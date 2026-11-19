use io;
use spi;
import "./mcp3008.j" as adc;

def dev as spi.Device init spi.open("/dev/spidev0.0"); # CE0
spi.configure($dev, 0, 1000000); # mode 0, 1 MHz
defer spi.close($dev);
for (def ch in 0..2) {
    def raw as int init adc.read($dev, $ch); # spi.transfer
    io.printf("ch%d %d|pad=4  %f|prec=2 V\n", $ch, $raw,
        $raw * 3.3 / 1024);
}
