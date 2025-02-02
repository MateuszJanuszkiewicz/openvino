#include <openvino/openvino.hpp>

int main() {
//! [part5]
ov::Core core;
ov::CompiledModel compileModel = core.compile_model("sample.xml", "MULTI:HDDL,GPU");
// query the optimal number of requests
uint32_t nireq = compileModel.get_property(ov::optimal_number_of_infer_requests);
//! [part5]
return 0;
}
