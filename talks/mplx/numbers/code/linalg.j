use io;
use linalg;

def temp as list of float init [19.0, 17.5, 23.0, 27.5, 26.0, 16.0,
    17.0, 21.0, 25.0, 29.0, 31.5, 18.5, 18.0];
def cones as list of float init [112.0, 98.0, 128.0, 165.0, 139.0,
    108.0, 118.0, 120.0, 151.0, 160.0, 196.0, 94.0, 121.0];
def X as list of list of float init [];
for (def t in $temp) { $X[] = [1.0, $t]; }      # a column of ones
def Xt as list of list of float init linalg.transpose($X);
def beta as list of float init linalg.solve(linalg.matmul($Xt, $X),
    linalg.matmul($Xt, $cones));
io.printf("intercept %f|prec=2, slope %f|prec=2\n", $beta[0], $beta[1]);
def res as list of float init
    linalg.sub($cones, linalg.matmul($X, $beta));
io.printf("residual norm %f|prec=1\n", linalg.norm($res));
