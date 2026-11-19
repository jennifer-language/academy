for i in 1 2 3; do
  sleep 0.3; echo 0 > mock/gpio27/value
  sleep 0.3; echo 1 > mock/gpio27/value
done
