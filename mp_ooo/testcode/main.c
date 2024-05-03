int main() {
    // Write Some Longer Looping Code to Test Frontend and EBR without OoO branch queue
    int a = 0;
    int b = 0;
    int c = 0;
    int d = 0;;
    for (int i = 0; i < 100; i++) {
        a++;
        b++;
        c++;
        d++;
    }

    if (a >= b) {
        return 0;
    } else if (c >= d) {
        return -1;
    } else {
        return -2;
    }
}