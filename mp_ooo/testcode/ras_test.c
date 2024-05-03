int test(int q);
int test1(int q);
int test2(int q);
int test3(int q);

int test(int q) {
  return q+1;
}
int test1(int q) {
  return q+2;
}
int test2(int q) {
  q = test(q);
  return q+3;
}
int test3(int q) {
  q = test2(q);
  return q-4;
}

int main() {
  int a;
  int b;
  a = 0;
  b = 1;
  a = b + 1;

  for (int i=0;i<100;i++) {
    a = test(a);
    a = test1(a);
    a = test2(a);
    a = test3(a);
    //a = a + 1;
  }

  b = a + 1;

  int ah;

  ah = b;

  return ah;
}


