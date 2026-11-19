use gpio;
gpio.setup(17, gpio.OUT);
gpio.write(17, 1);
gpio.release(17);
