#include <vector>

class DoublePointerIter {
public:
    DoublePointerIter(double* start, int len) : start_(start), len_(len) { }
    double* begin() { return start_; }
    double* end() { return start_ + len_; }
private:
    double* start_;
    int len_;
};

class HasIterableAttribute {
public:
    std::vector<int> vec;
    HasIterableAttribute() : vec({1, 2, 3}) {}
};

