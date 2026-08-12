#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>

#include "c10/macros/Macros.h"

namespace caffe2 {
namespace serialize {

// A read-only memory mapping of a whole archive file. Tensor storages may alias
// the mapping instead of owning a copy of the record bytes, so the mapping has
// to outlive every storage that points into it. Ownership is therefore shared:
// each aliasing storage holds a strong reference and the region is unmapped once
// the last one goes away.
class TORCH_API MmapRegion final {
 public:
  MmapRegion(void* addr, size_t size) : addr_(addr), size_(size) {}
  ~MmapRegion();
  MmapRegion(const MmapRegion&) = delete;
  MmapRegion& operator=(const MmapRegion&) = delete;

  void* addr() const {
    return addr_;
  }
  size_t size() const {
    return size_;
  }

 private:
  void* addr_;
  size_t size_;
};

// this is the interface for the (file/stream/memory) reader in
// PyTorchStreamReader. with this interface, we can extend the support
// besides standard istream
class TORCH_API ReadAdapterInterface {
 public:
  virtual size_t size() const = 0;
  virtual size_t read(uint64_t pos, void* buf, size_t n, const char* what = "")
      const = 0;
  // Non-null only when the whole archive is backed by a memory mapping, which
  // lets callers hand out tensor storages that alias the file instead of
  // copying record bytes onto the heap. Adapters that cannot offer this (the
  // default) return nullptr and callers fall back to copying.
  virtual std::shared_ptr<MmapRegion> mmapRegion() const {
    return nullptr;
  }
  virtual ~ReadAdapterInterface();
};

} // namespace serialize
} // namespace caffe2
