#pragma once

#include <c10/macros/Macros.h>
#include <fstream>
#include <memory>

#include "caffe2/serialize/istream_adapter.h"
#include "caffe2/serialize/read_adapter_interface.h"

namespace caffe2 {
namespace serialize {

class TORCH_API FileAdapter final : public ReadAdapterInterface {
 public:
  C10_DISABLE_COPY_AND_ASSIGN(FileAdapter);
  explicit FileAdapter(const std::string& file_name);
  size_t size() const override;
  size_t read(uint64_t pos, void* buf, size_t n, const char* what = "")
      const override;
  ~FileAdapter() override;

 private:
  // An RAII Wrapper for a FILE pointer. Closes on destruction.
  struct RAIIFile {
    FILE* fp_;
    explicit RAIIFile(const std::string& file_name);
    ~RAIIFile();
  };

  RAIIFile file_;
  // The size of the opened file in bytes
  uint64_t size_;
};

#if !defined(_WIN32)
// Reads an archive through a read-only memory mapping of the file. Reads are
// served as plain memcpy out of the mapping, and because the mapping is exposed
// via mmapRegion() the loader can additionally point uncompressed tensor
// storages straight at it, avoiding a heap copy of the weights.
class TORCH_API MmapReadAdapter final : public ReadAdapterInterface {
 public:
  C10_DISABLE_COPY_AND_ASSIGN(MmapReadAdapter);
  explicit MmapReadAdapter(const std::string& file_name);
  size_t size() const override;
  size_t read(uint64_t pos, void* buf, size_t n, const char* what = "")
      const override;
  std::shared_ptr<MmapRegion> mmapRegion() const override;
  ~MmapReadAdapter() override;

 private:
  std::shared_ptr<MmapRegion> region_;
};
#endif // !_WIN32

} // namespace serialize
} // namespace caffe2
