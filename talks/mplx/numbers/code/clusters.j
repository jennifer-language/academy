use io;
use math;
use ml;

# [average basket in EUR, visits per month] for eight customers
def X as list of list of float init [[4.2, 22.0], [3.8, 25.0],
    [4.5, 19.0], [18.0, 3.0], [21.5, 2.0], [16.0, 4.0], [9.0, 10.0],
    [10.5, 8.0]];
math.randSeed(7);
def scaler as ml.Model init ml.standardScaler($X);
def Z as list of list of float init ml.transform($scaler, $X);
def km as ml.Model init ml.kMeans($Z, 3);
io.printf("clusters %a\n", ml.predict($km, $Z));
def nb as ml.Model init ml.kNN($Z, ml.predict($km, $Z), 3);
io.printf("new customer -> %a\n",
    ml.predict($nb, ml.transform($scaler, [[17.0, 5.0]])));
