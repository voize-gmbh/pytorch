#pragma once
#include <torch/csrc/jit/mobile/function.h>

namespace torch::jit {
using c10::IValue;

enum MobileModuleLoadOptions {
  OPERATOR_CHECK = 1,
  // PARSE_ALL_EXTRA_FILE_MAPS is used to gate for ExtraFileMaps to pull all
  // files automatically without explicit entries mapping. Refer to PR for a
  // detail: https://github.com/pytorch/pytorch/pull/99747
  PARSE_ALL_EXTRA_FILE_MAPS = 2,
  // USE_MMAP memory-maps the model file and lets tensor storages alias the
  // mapping instead of copying the weights onto the heap. Only affects loading
  // from a file path, and only records that are stored uncompressed and
  // aligned; anything else still gets copied. Weight pages then stay clean and
  // file-backed, so the OS can evict them under memory pressure.
  USE_MMAP = 4,
};

const uint64_t kDefaultMobileLoadOptions =
    MobileModuleLoadOptions::OPERATOR_CHECK;

namespace mobile {

TORCH_API void parseOperators(
    c10::ivalue::TupleElements&& ops_list,
    const uint64_t& module_load_options,
    mobile::Function* function);
} // namespace mobile
} // namespace torch::jit
