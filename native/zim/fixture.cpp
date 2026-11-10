// Original synthetic test content; no encyclopedia content or identification images.
#include <zim/writer/creator.h>
#include <zim/writer/item.h>
#include <memory>
int main(int argc, char** argv) {
  if (argc != 2) return 2;
  zim::writer::Creator creator;
  creator.configIndexing(true, "eng");
  creator.startZimCreation(argv[1]);
  creator.addMetadata("Title", "Dooms Day native test fixture");
  creator.addMetadata("Language", "eng");
  creator.addMetadata("Date", "2026-10-20");
  creator.addMetadata("Creator", "Dooms Day App test suite");
  creator.addItem(zim::writer::StringItem::create("rice.html", "text/html", "Rice fixture",
    zim::writer::Hints{}, "<html><head><title>Rice fixture</title></head><body><h1>Rice</h1><p>Brown rice test content.</p></body></html>"));
  creator.addItem(zim::writer::StringItem::create("python.html", "text/html", "Python fixture",
    zim::writer::Hints{}, "<html><head><title>Python fixture</title></head><body><p>Python inventory test content.</p></body></html>"));
  creator.setMainPath("rice.html");
  creator.finishZimCreation();
}
