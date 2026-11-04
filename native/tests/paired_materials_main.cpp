// Standalone entry point for bounded material qualification. The full native
// runner continues to call the same suite from test_world.cpp.
#include <exception>
#include <iostream>

void run_paired_material_tests();

int main() {
    std::cout.setf(std::ios::unitbuf);
    try {
        run_paired_material_tests();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "PAIR_CURE failure: " << error.what() << '\n';
        return 1;
    }
}
