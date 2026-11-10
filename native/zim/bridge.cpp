// Native archive prototype. Link against libzim (GPL-2.0-or-later).
// This bridge is not automatically linked into production app builds.
#include <zim/archive.h>
#include <zim/item.h>
#include <zim/search.h>
#include <zim/search_iterator.h>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <stdexcept>
#include <string>

#if defined(_WIN32)
#define API __declspec(dllexport)
#else
#define API __attribute__((visibility("default"))) __attribute__((used))
#endif
static std::string quote(const std::string& input) {
  std::ostringstream out;
  out << '"';
  const char* hex = "0123456789abcdef";
  for (unsigned char c : input) {
    if (c == '"' || c == '\\') out << '\\' << c;
    else if (c < 32) out << "\\u00" << hex[c >> 4] << hex[c & 15];
    else out << c;
  }
  out << '"';
  return out.str();
}
static char* copy(const std::string& value) {
  char* result = static_cast<char*>(std::malloc(value.size() + 1));
  if (!result) return nullptr;
  std::memcpy(result, value.c_str(), value.size() + 1);
  return result;
}
extern "C" API void dd_zim_free(void* pointer) { std::free(pointer); }
extern "C" API char* dd_zim_request(const char* path, const char* operation,
                                    const char* argument, int offset, int count) {
  try {
    if (!path || !operation || !argument) throw std::invalid_argument("Missing argument");
    zim::Archive archive(path); // mmap/on-demand clusters; no whole-archive copy.
    const std::string op(operation);
    if (op == "inspect") {
      std::string result = "{\"article_count\":" + std::to_string(archive.getArticleCount()) +
        ",\"fulltext\":" + (archive.hasFulltextIndex() ? "true" : "false");
      for (const char* key : {"Title", "Language", "Date", "Creator", "Publisher", "Description"}) {
        try { result += "," + quote(key) + ":" + quote(archive.getMetadata(key)); }
        catch (const std::exception&) { /* Optional metadata is genuinely absent. */ }
      }
      return copy(result + "}");
    }
    if (op == "search") {
      if (offset < 0 || count < 1 || count > 100) throw std::invalid_argument("Invalid page bounds");
      if (!archive.hasFulltextIndex()) throw std::runtime_error("Archive has no full-text index");
      zim::Searcher searcher(archive);
      zim::Query query;
      query.setQuery(argument);
      const auto results = searcher.search(query).getResults(offset, count);
      std::string json = "{\"results\":[";
      bool first = true;
      for (auto entry = results.begin(); entry != results.end(); ++entry) {
        if (!first) json += ",";
        first = false;
        json += "{\"path\":" + quote(entry.getPath()) + ",\"title\":" + quote(entry.getTitle()) + "}";
      }
      return copy(json + "]}");
    }
    if (op == "read") {
      auto item = archive.getEntryByPath(argument).getItem(true);
      if (item.getSize() > 16 * 1024 * 1024) throw std::runtime_error("Entry exceeds 16 MB reader limit");
      const auto mime = item.getMimetype();
      if (mime.find("text/") != 0 && mime != "application/xhtml+xml")
        throw std::runtime_error("Use the asset API for binary entries");
      auto blob = item.getData();
      return copy("{\"mime\":" + quote(mime) + ",\"text\":" +
                  quote(std::string(blob.data(), blob.size())) + "}");
    }
    throw std::invalid_argument("Unsupported operation");
  } catch (const std::exception& error) {
    return copy("{\"error\":" + quote(error.what()) + "}");
  } catch (...) { return copy("{\"error\":\"Native archive error\"}"); }
}
extern "C" API unsigned char* dd_zim_asset(const char* path, const char* entry,
                                           unsigned long long* size) {
  if (!size) return nullptr;
  *size = 0;
  try {
    zim::Archive archive(path);
    auto item = archive.getEntryByPath(entry).getItem(true);
    if (item.getSize() > 16 * 1024 * 1024) return nullptr;
    auto blob = item.getData();
    auto result = static_cast<unsigned char*>(std::malloc(blob.size()));
    if (!result) return nullptr;
    std::memcpy(result, blob.data(), blob.size());
    *size = blob.size();
    return result;
  } catch (...) { return nullptr; }
}
