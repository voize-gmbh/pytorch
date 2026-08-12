#include "caffe2/serialize/read_adapter_interface.h"

#if !defined(_WIN32)
#include <sys/mman.h>
#endif

namespace caffe2 {
namespace serialize {

MmapRegion::~MmapRegion() {
#if !defined(_WIN32)
  if (addr_ != nullptr) {
    munmap(addr_, size_);
  }
#endif
}

// NOLINTNEXTLINE(modernize-use-equals-default)
ReadAdapterInterface::~ReadAdapterInterface() {}

} // namespace serialize
} // namespace caffe2
